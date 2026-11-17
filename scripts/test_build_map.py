"""Tests for scripts/build-map.py. Run: python3 -m unittest scripts/test_build_map.py -v"""

import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "build-map.py"
spec = importlib.util.spec_from_file_location("build_map", SCRIPT)
assert spec is not None and spec.loader is not None
build_map = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_map)

DEFAULT_MAP = json.loads(
    (ROOT / "Bomberman-2.0-Backend/src/maps/default_map.json").read_text()
)

# 12 x 8 map: border walls, two spawns with escape cells, one portal box.
GOOD = """\
############
#S..oo...S.#
#.#.oo.#.#.#
#..........#
#.#o##o#.#.#
#..........#
#P.oo...oo.#
############
"""


def grid(text):
    return build_map.parse_grid(text)


class RoundTrip(unittest.TestCase):
    def test_round_trip_default_map(self):
        text = build_map.grid_from_tiled(DEFAULT_MAP)
        tiled = build_map.to_tiled(grid(text), 14)
        layer, original = tiled["layers"][0], DEFAULT_MAP["layers"][0]
        self.assertEqual(layer["data"], original["data"])
        self.assertEqual((layer["width"], layer["height"]), (32, 21))
        self.assertEqual(
            sorted((s["col"], s["row"]) for s in layer["properties"]["spawns"]),
            sorted((s["col"], s["row"]) for s in original["properties"]["spawns"]),
        )


class Validate(unittest.TestCase):
    def errors(self, text, players=2, min_distance=5):
        return build_map.validate(grid(text), players, min_distance)

    def test_good_grid_is_valid(self):
        self.assertEqual(self.errors(GOOD), [])

    def test_validate_rejects_open_border(self):
        self.assertTrue(
            any("border" in e for e in self.errors(GOOD.replace("############\n", "#####.######\n", 1)))
        )

    def test_validate_rejects_closed_area(self):
        text = """\
############
#S..oo...S.#
#.#.oo.###.#
#......#.#.#
#.#o##o###.#
#..........#
#P.oo...oo.#
############
"""
        self.assertTrue(any("not connected" in e for e in self.errors(text)))

    def test_validate_rejects_spawn_without_escape(self):
        text = GOOD.replace("#S..oo", "#So.oo", 1).replace("#.#.oo", "#o#.oo", 1)
        self.assertTrue(any("escape" in e for e in self.errors(text)))

    def test_validate_rejects_too_few_spawns(self):
        self.assertTrue(any("spawns" in e for e in self.errors(GOOD, players=3)))

    def test_portal_cell_becomes_a_box(self):
        layer = build_map.to_tiled(grid(GOOD), 2)["layers"][0]
        self.assertEqual(layer["data"][6 * 12 + 1], 5)
        self.assertEqual(build_map.portals(grid(GOOD)), [{"row": 6, "col": 1}])

    def test_spawn_entries_have_the_offset(self):
        layer = build_map.to_tiled(grid(GOOD), 2)["layers"][0]
        self.assertEqual(layer["properties"]["spawns"][0], {"col": 2, "row": 2})
        self.assertEqual(layer["data"][1 * 12 + 1], 6)

    def test_validate_rejects_close_spawns(self):
        text = GOOD.replace("#S..oo...S.#", "#S..S..oo..#", 1)
        self.assertTrue(any("distance" in e for e in self.errors(text)))

    def test_validate_rejects_bad_width(self):
        text = GOOD.replace("#S..oo...S.#", "#S..oo...S..#", 1)
        self.assertTrue(any("width" in e for e in self.errors(text)))


class Check(unittest.TestCase):
    def test_check_fails_when_the_copies_differ(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = pathlib.Path(tmp)
            (tmp / "scripts/maps").mkdir(parents=True)
            (tmp / "scripts/maps/tiny.txt").write_text(GOOD)
            (tmp / "Bomberman-2.0-Backend/src/maps").mkdir(parents=True)
            (tmp / "Bomberman-2.0/public/assets/maps").mkdir(parents=True)
            run = lambda *a: subprocess.run(
                [sys.executable, str(SCRIPT), "tiny", "--players", "2", "--root", str(tmp), *a],
                capture_output=True,
                text=True,
            )
            (tmp / "Bomberman-2.0-Backend/src").mkdir(parents=True, exist_ok=True)
            (tmp / "Bomberman-2.0-Backend/src/constants.ts").write_text(
                "export const TINY_PORTAL_SPAWNS = [\n  { row: 6, col: 1 },\n];\n"
            )
            self.assertEqual(run().returncode, 0)
            self.assertEqual(run("--check").returncode, 0)
            client = tmp / "Bomberman-2.0/public/assets/maps/tiny.json"
            client.write_text(client.read_text().replace('"max_players": 2', '"max_players": 3'))
            self.assertNotEqual(run("--check").returncode, 0)

    def test_check_fails_when_the_portal_constant_differs(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = pathlib.Path(tmp)
            (tmp / "scripts/maps").mkdir(parents=True)
            (tmp / "scripts/maps/tiny.txt").write_text(GOOD)
            (tmp / "Bomberman-2.0-Backend/src/maps").mkdir(parents=True)
            (tmp / "Bomberman-2.0/public/assets/maps").mkdir(parents=True)
            constants = tmp / "Bomberman-2.0-Backend/src/constants.ts"
            constants.write_text("export const TINY_PORTAL_SPAWNS = [\n  { row: 5, col: 1 },\n];\n")
            run = lambda *a: subprocess.run(
                [sys.executable, str(SCRIPT), "tiny", "--players", "2", "--root", str(tmp), *a],
                capture_output=True,
                text=True,
            )
            run()
            result = run("--check")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("TINY_PORTAL_SPAWNS", result.stderr)


if __name__ == "__main__":
    unittest.main()
