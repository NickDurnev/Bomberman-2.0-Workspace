#!/usr/bin/env bash
# Check that docs/socket-contract.md lists exactly the socket.io events that the
# code uses, in both submodules.
#
# Run from anywhere: ./scripts/check-socket-contract.sh   (no arguments)
# Exit 0: the doc table and the code agree.
# Exit 1: they differ (the diff is printed), or an event name could not be
#         resolved to a plain string.
#
# What counts as "used in code":
#   - .on / .once / .off / .emit on a socket receiver (clientSocket, socket,
#     client, sockets, broadcast, serverSocket, io), with the event name as the
#     first argument: a "double", 'single' or `template` string literal,
#   - server broadcasts: io.to(...).emit / io.in(...).emit, also when .emit(...)
#     starts a new line of a chained call,
#   - multi-line calls: the call opens with `.on(` (or once/off/emit) at the end
#     of a line and the event name is the first thing on the next line,
#   - an UPPER_CASE constant as the event name (resolved via `NAME = "..."` or
#     `NAME: "..."` anywhere in the sources),
#   - a local variable as the event name (e.g. a loop over a handler table):
#     the names come from `["event", handler]` entries in the same file.
# socket.io built-in events (connect, disconnect, connection, ...) are not part
# of the contract and are ignored.
#
# Limits (what this check does NOT verify):
#   - Only the SET OF EVENT NAMES is compared. The direction, payload, emitter
#     and handler columns of the doc table are not checked.
#   - Receivers are matched by name (list above). A socket held in a variable
#     with another name (e.g. `s.emit("x")`) is not seen.
#   - A template literal with ${...} in the event name, or a first argument on
#     the next line that is neither a string nor an identifier, fails closed
#     (exit 1) instead of being guessed.
#   - A first argument more than one line after the opening `(` is not seen.
#
# Portable: POSIX grep -E / sed -E / awk / sort / comm only (GNU and BSD).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DOC="docs/socket-contract.md"
SRC_DIRS="Bomberman-2.0/src Bomberman-2.0-Backend/src"
BUILTIN='^(connect|connect_error|connection|disconnect|disconnecting|error|ping|reconnect|reconnect_attempt|reconnect_error|reconnect_failed|newListener|removeListener)$'

# The receiver must start at a word boundary, so `ratio.on(` does not match `io`.
RECV='(^|[^A-Za-z0-9_])(clientSocket|socket|client|sockets|broadcast|serverSocket|io)'
METHOD='(on|once|off|emit)'
SP='[[:space:]]*'
Q="[\"'\`]"         # opening or closing quote: " ' or backtick
STR="${Q}[^\"'\`]+${Q}"
IDENT='[A-Za-z_][A-Za-z0-9_.]*'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

src_grep() {
  # Search all TypeScript sources; print nothing (not fail) when no match.
  # shellcheck disable=SC2086
  grep -rE --include='*.ts' --include='*.tsx' "$@" $SRC_DIRS || true
}

strip_quotes() {
  # Keep the text of the last string literal on each line (grep -o output
  # holds exactly one).
  sed -E "s/^.*${Q}([^\"'\`]+)${Q}.*$/\1/"
}

list_sources() {
  # shellcheck disable=SC2086
  find $SRC_DIRS -type f \( -name '*.ts' -o -name '*.tsx' \)
}

unresolved=0

: > "$tmp/idents"

# 1. String literals on a socket receiver: clientSocket.on("x", ...).
src_grep -ho "${RECV}\.${METHOD}\(${SP}${STR}" | strip_quotes > "$tmp/code"

# 2. Server broadcasts on a room: serverSocket.to(id).emit("x") / .in(id).emit("x").
src_grep -ho "\)\.emit\(${SP}${STR}" | strip_quotes >> "$tmp/code"

# 3. Chained call continued on a new line: `    .emit("x", ...)`.
src_grep -h "^${SP}\.emit\(${SP}${STR}" | strip_quotes >> "$tmp/code"

# 4. Multi-line calls: `client.on(` at the end of a line, the event name first
#    on the next line. Literals go to the list; identifiers go to step 5;
#    anything else fails closed.
list_sources | while IFS= read -r f; do
  awk -v recv="$RECV" -v method="$METHOD" '
    FNR == 1 { prev = "" }
    {
      if (prev ~ (recv "\\." method "\\([[:space:]]*$") ||
          prev ~ ("(^[[:space:]]*|\\))\\.emit\\([[:space:]]*$")) {
        line = $0
        sub(/^[[:space:]]+/, "", line)
        print FILENAME ":" FNR ":" line
      }
      prev = $0
    }' "$f"
done > "$tmp/nextline"

while IFS= read -r hit; do
  loc="$(printf '%s\n' "$hit" | cut -d: -f1-2)"
  arg="$(printf '%s\n' "$hit" | cut -d: -f3-)"
  if printf '%s\n' "$arg" | grep -qE "^${STR}"; then
    printf '%s\n' "$arg" | sed -E "s/^${Q}([^\"'\`]+)${Q}.*$/\1/" >> "$tmp/code"
  elif printf '%s\n' "$arg" | grep -qE "^${IDENT}${SP}[,)]"; then
    ident="$(printf '%s\n' "$arg" | sed -E "s/^(${IDENT}).*$/\1/")"
    printf '%s:x.on(%s,\n' "$loc" "$ident" >> "$tmp/idents"
  else
    echo "ERROR: cannot read the event name of the multi-line call at $loc: $arg" >&2
    unresolved=1
  fi
done < "$tmp/nextline"

# 5. Non-literal event names: constants or handler-table variables.
src_grep -no "${RECV}\.${METHOD}\(${SP}${IDENT}${SP}," >> "$tmp/idents"
while IFS= read -r hit; do
  file="${hit%%:*}"
  ident="$(printf '%s\n' "$hit" | sed -E "s/.*\.${METHOD}\(${SP}(${IDENT})${SP},$/\2/")"
  if printf '%s\n' "$ident" | grep -qE '^([A-Za-z0-9_]+\.)*[A-Z][A-Z0-9_]*$'; then
    # Constant, e.g. EVENT_MOVE or EVENTS.MOVE: resolve its string value.
    name="${ident##*.}"
    value="$(src_grep -hoE "(^|[^A-Za-z0-9_])${name}${SP}[=:]${SP}${STR}" | strip_quotes | sort -u)"
    if [ -z "$value" ]; then
      echo "ERROR: cannot resolve event constant '$ident' ($hit)" >&2
      unresolved=1
    else
      printf '%s\n' "$value" >> "$tmp/code"
    fi
  else
    # Local variable, e.g. `for (const [event, handler] of table) socket.on(event, handler)`.
    names="$(grep -oE "\[${SP}${STR}${SP}," "$file" | strip_quotes | sort -u || true)"
    if [ -z "$names" ]; then
      echo "ERROR: cannot resolve event variable '$ident' ($hit)" >&2
      unresolved=1
    else
      printf '%s\n' "$names" >> "$tmp/code"
    fi
  fi
done < "$tmp/idents"

# Fail closed on template literals with interpolation: the name is not static.
if grep -q '[$][{]' "$tmp/code"; then
  echo "ERROR: event name built with \${...} cannot be checked:" >&2
  grep '[$][{]' "$tmp/code" | sed 's/^/  /' >&2
  unresolved=1
fi

grep -vE "$BUILTIN" "$tmp/code" | sort -u > "$tmp/code.sorted" || true

# Doc events: first-column backtick names of table rows between the markers.
if [ -f "$DOC" ]; then
  sed -n '/<!-- socket-contract:begin -->/,/<!-- socket-contract:end -->/p' "$DOC" \
    | grep -E "^\|${SP}\`[^\`]+\`" \
    | sed -E "s/^\|${SP}\`([^\`]+)\`.*$/\1/" \
    | sort -u > "$tmp/doc.sorted" || true
else
  echo "WARNING: $DOC does not exist" >&2
  : > "$tmp/doc.sorted"
fi

missing="$(comm -23 "$tmp/code.sorted" "$tmp/doc.sorted")"
stale="$(comm -13 "$tmp/code.sorted" "$tmp/doc.sorted")"

if [ -n "$missing" ]; then
  echo "Events used in code but missing from $DOC:"
  printf '%s\n' "$missing" | sed 's/^/  + /'
fi
if [ -n "$stale" ]; then
  echo "Events in $DOC but not used in code:"
  printf '%s\n' "$stale" | sed 's/^/  - /'
fi

if [ -n "$missing" ] || [ -n "$stale" ] || [ "$unresolved" -ne 0 ]; then
  exit 1
fi

echo "OK: $DOC matches the code ($(wc -l < "$tmp/code.sorted" | tr -d ' ') events)."
