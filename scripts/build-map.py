#!/usr/bin/env python3
"""Build a Bomberman map from a hand-drawn text grid.

The grid lives in scripts/maps/<name>.txt:
  #  wall    o  box    .  empty
  S  spawn cell (empty)
  P  portal cell (a box; a portal appears when it breaks)

The script checks the grid, writes the server and client Tiled JSON copies
and, with --png, renders the menu preview. See docs/maps.md.

  python3 scripts/build-map.py big_map --players 20 --png
  python3 scripts/build-map.py big_map --players 20 --check
"""

import argparse
import json
import pathlib
import re
import subprocess
import sys
from collections import deque

WALL, BOX, EMPTY = 1, 5, 6
TILE = 35
TILE_OF = {"#": WALL, "o": BOX, ".": EMPTY, "S": EMPTY, "P": BOX}
ROOT = pathlib.Path(__file__).resolve().parent.parent
SERVER_DIR = "Bomberman-2.0-Backend/src/maps"
CLIENT_DIR = "Bomberman-2.0/public/assets/maps"
PREVIEW_DIR = "Bomberman-2.0/public/assets/images/menu"


def parse_grid(text):
    return [list(line) for line in text.splitlines() if line.strip()]


def cells(grid, symbol):
    return [(c, r) for r, row in enumerate(grid) for c, ch in enumerate(row) if ch == symbol]


def portals(grid):
    return [{"row": r, "col": c} for c, r in cells(grid, "P")]


def neighbours(c, r):
    return [(c + 1, r), (c - 1, r), (c, r + 1), (c, r - 1)]


def validate(grid, players, min_distance=5):
    errors = []
    height, width = len(grid), len(grid[0]) if grid else 0
    for r, row in enumerate(grid):
        if len(row) != width:
            errors.append(f"row {r}: width {len(row)}, expected {width}")
        for c, ch in enumerate(row):
            if ch not in TILE_OF:
                errors.append(f"cell {c},{r}: unknown symbol {ch!r}")
    if errors:
        return errors

    def at(c, r):
        return grid[r][c] if 0 <= r < height and 0 <= c < width else "#"

    for r in range(height):
        for c in range(width):
            on_border = r in (0, height - 1) or c in (0, width - 1)
            if on_border and grid[r][c] != "#":
                errors.append(f"cell {c},{r}: the border must be walls")

    spawns = cells(grid, "S")
    if len(spawns) < players:
        errors.append(f"{len(spawns)} spawns, need at least {players}")

    # Boxes break, so every non-wall cell must be reachable from a spawn.
    open_cells = {(c, r) for r in range(height) for c in range(width) if grid[r][c] != "#"}
    if spawns:
        seen, queue = {spawns[0]}, deque([spawns[0]])
        while queue:
            for n in neighbours(*queue.popleft()):
                if n in open_cells and n not in seen:
                    seen.add(n)
                    queue.append(n)
        missing = open_cells - seen
        if missing:
            errors.append(f"{len(missing)} cells not connected, e.g. {sorted(missing)[0]}")

    for c, r in spawns:
        # A bomb of power 1 reaches the next cell: the player needs an empty
        # cell two steps away (straight or round a corner) to stand in.
        safe = any(
            at(*n) in ".S" and any(at(*m) in ".S" and m != (c, r) for m in neighbours(*n))
            for n in neighbours(c, r)
        )
        if not safe:
            errors.append(f"spawn {c},{r}: no escape cell")
    for i, (c1, r1) in enumerate(spawns):
        for c2, r2 in spawns[i + 1 :]:
            if abs(c1 - c2) + abs(r1 - r2) < min_distance:
                errors.append(f"spawns {c1},{r1} and {c2},{r2}: distance below {min_distance}")
    return errors


def portal_constant(root, name):
    """The server's portal list for a map, read from constants.ts (None if absent)."""
    constant = f"{name.upper()}_PORTAL_SPAWNS"
    path = root / "Bomberman-2.0-Backend/src/constants.ts"
    match = path.exists() and re.search(rf"{constant} = \[(.*?)\];", path.read_text(), re.S)
    if not match:
        return constant, None
    cells = re.findall(r"row:\s*(\d+),\s*col:\s*(\d+)", match.group(1))
    return constant, [{"row": int(r), "col": int(c)} for r, c in cells]


def to_tiled(grid, players):
    height, width = len(grid), len(grid[0])
    return {
        "width": width,
        "height": height,
        "tilewidth": TILE,
        "tileheight": TILE,
        "layers": [
            {
                "name": "Blocks",
                "width": width,
                "height": height,
                "x": 0,
                "y": 0,
                "opacity": 1,
                "type": "tilelayer",
                "visible": True,
                "data": [TILE_OF[ch] for row in grid for ch in row],
                "properties": {
                    "max_players": players,
                    "collisionTiles": [WALL, BOX],
                    "empty": EMPTY,
                    "box": BOX,
                    "wall": WALL,
                    # Spawn offset: the client draws the player at (col - 1, row - 1).
                    "spawns": [{"col": c + 1, "row": r + 1} for c, r in cells(grid, "S")],
                },
            }
        ],
        "renderorder": "right-down",
        "tilesets": [
            {
                "name": "tiles",
                "firstgid": 1,
                "tilewidth": TILE,
                "tileheight": TILE,
                "imagewidth": 210,
                "imageheight": TILE,
                "image": "tileset.png",
                "margin": 0,
                "properties": {},
                "spacing": 0,
            }
        ],
        "properties": {},
        "orientation": "orthogonal",
        "version": 1,
    }


def grid_from_tiled(tiled):
    layer = tiled["layers"][0]
    width = layer["width"]
    symbol = {WALL: "#", BOX: "o"}
    rows = [
        [symbol.get(t, ".") for t in layer["data"][r * width : (r + 1) * width]]
        for r in range(layer["height"])
    ]
    for s in layer["properties"]["spawns"]:
        rows[s["row"] - 1][s["col"] - 1] = "S"
    return "\n".join("".join(row) for row in rows) + "\n"


def render_png(grid, path, scale=2):
    from PIL import Image  # pyright: ignore[reportMissingImports]  (only for --png)

    tileset = Image.open(ROOT / CLIENT_DIR / "tileset.png").convert("RGBA")
    tile = {t: tileset.crop(((t - 1) * TILE, 0, t * TILE, TILE)) for t in (WALL, BOX, EMPTY)}
    image = Image.new("RGBA", (len(grid[0]) * TILE, len(grid) * TILE))
    for r, row in enumerate(grid):
        for c, ch in enumerate(row):
            image.paste(tile[TILE_OF[ch]], (c * TILE, r * TILE))
    image = image.resize((image.width * scale, image.height * scale), Image.NEAREST)
    image.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("name")
    parser.add_argument("--players", type=int, required=True)
    parser.add_argument("--min-distance", type=int, default=5)
    parser.add_argument("--png", action="store_true", help="also render the menu preview")
    parser.add_argument("--check", action="store_true", help="validate and compare the existing copies")
    parser.add_argument("--root", type=pathlib.Path, default=ROOT)
    args = parser.parse_args()

    grid = parse_grid((args.root / "scripts/maps" / f"{args.name}.txt").read_text())
    errors = validate(grid, args.players, args.min_distance)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    tiled = to_tiled(grid, args.players)
    copies = [args.root / SERVER_DIR / f"{args.name}.json", args.root / CLIENT_DIR / f"{args.name}.json"]

    if args.check:
        # The backend copy is Biome-formatted, so compare content, not bytes.
        bad = [p for p in copies if not p.exists() or json.loads(p.read_text()) != tiled]
        for p in bad:
            print(f"{p}: differs from scripts/maps/{args.name}.txt", file=sys.stderr)
        constant, server_portals = portal_constant(args.root, args.name)
        drawn = sorted(portals(grid), key=lambda p: (p["row"], p["col"]))
        if server_portals is not None and sorted(server_portals, key=lambda p: (p["row"], p["col"])) != drawn:
            print(f"{constant} in constants.ts differs from the P cells: {json.dumps(drawn)}", file=sys.stderr)
            bad.append(constant)
        return 1 if bad else 0

    for p in copies:
        p.write_text(json.dumps(tiled, indent=2) + "\n")
    biome = args.root / "Bomberman-2.0-Backend/node_modules/.bin/biome"
    if biome.exists():
        subprocess.run([str(biome), "format", "--write", str(copies[0])], cwd=copies[0].parents[2], check=True, capture_output=True)
    if args.png:
        render_png(grid, args.root / PREVIEW_DIR / f"{args.name}_preview.png")

    total = len(grid) * len(grid[0])
    walls, boxes = sum(row.count("#") for row in grid), sum(row.count("o") + row.count("P") for row in grid)
    print(f"{args.name}: {len(grid[0])} x {len(grid)}, walls {walls / total:.0%}, boxes {boxes / total:.0%}, spawns {len(cells(grid, 'S'))}")
    print("portal cells:", json.dumps(portals(grid)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
