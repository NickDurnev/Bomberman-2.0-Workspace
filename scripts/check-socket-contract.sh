#!/usr/bin/env bash
# Check that docs/socket-contract.md lists exactly the socket.io events that the
# code uses, in both submodules.
#
# Run from anywhere: ./scripts/check-socket-contract.sh   (no arguments)
# Exit 0: the doc table and the code agree.
# Exit 1: they differ (the diff is printed), or an event name could not be
#         resolved to a string.
#
# What counts as "used in code":
#   - socket.on / once / off / emit with a string literal as the first argument,
#     on a socket receiver (clientSocket, socket, client, sockets, broadcast),
#   - server broadcasts: io.to(...).emit / io.in(...).emit, also when the
#     .emit(...) starts a new line of a chained call,
#   - an UPPER_CASE constant as the event name (resolved via `NAME = "..."` or
#     `NAME: "..."` anywhere in the sources),
#   - a local variable as the event name (e.g. a loop over a handler table):
#     the names come from `["event", handler]` entries in the same file.
# socket.io built-in events (connect, disconnect, connection, ...) are not part
# of the contract and are ignored.
#
# Portable: POSIX grep -E / sed / sort / comm only (GNU and BSD).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DOC="docs/socket-contract.md"
SRC_DIRS="Bomberman-2.0/src Bomberman-2.0-Backend/src"
BUILTIN='^(connect|connect_error|connection|disconnect|disconnecting|error|ping|reconnect|reconnect_attempt|reconnect_error|reconnect_failed|newListener|removeListener)$'

RECV='(clientSocket|socket|client|sockets|broadcast)'
METHOD='(on|once|off|emit)'
SP='[[:space:]]*'
STR="[\"'][^\"']+[\"']"
IDENT='[A-Za-z_][A-Za-z0-9_.]*'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

src_grep() {
  # Search all TypeScript sources; print nothing (not fail) when no match.
  # shellcheck disable=SC2086
  grep -rE --include='*.ts' --include='*.tsx' "$@" $SRC_DIRS || true
}

strip_quotes() {
  sed -E "s/^.*[\"']([^\"']+)[\"'].*$/\1/"
}

unresolved=0

# 1. String literals on a socket receiver: clientSocket.on("x", ...).
src_grep -ho "${RECV}\.${METHOD}\(${SP}${STR}" | strip_quotes > "$tmp/code"

# 2. Server broadcasts on a room: serverSocket.to(id).emit("x") / .in(id).emit("x").
src_grep -ho "\)\.emit\(${SP}${STR}" | strip_quotes >> "$tmp/code"

# 3. Chained call continued on a new line: `    .emit("x", ...)`.
src_grep -h "^${SP}\.emit\(${SP}${STR}" | strip_quotes >> "$tmp/code"

# 4. Non-literal event names: constants or handler-table variables.
src_grep -no "${RECV}\.${METHOD}\(${SP}${IDENT}${SP}," > "$tmp/idents"
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
