"""Render the level-select map thumbnails.

    python3 art/render_thumbnails.py

Output: data/icons/maps/<map_id>.png  - 256x256 RGBA, transparent margin.

NO BLENDER, AND NO PIL. THAT IS THE POINT.
------------------------------------------
The brief offered a choice: render the assembled board in Blender, or generate
from the .layout.txt directly. Directly, for three reasons, in order of weight:

  1. A 3D render of a 24x19 board shrunk to 256px is brown mud. What a player
     picking a level actually needs to see is the SHAPE OF THE ROUTE - where it
     enters, how it doubles back, how much build ground there is. A top-down
     diagram shows that at 256px; a photograph of it does not.
  2. The layout file is already the source of truth. game/board.gd, the
     pathfinder and MapDef.is_valid() all read it. Drawing from the same text
     means a thumbnail cannot disagree with the map - which a Blender rebuild,
     reimplementing placement a third time, absolutely could.
  3. It needs neither Blender nor a pip install. Any agent with python3 can
     regenerate the set, including in CI.

That third reason is why this deliberately writes PNG by hand with zlib and
struct rather than importing Pillow. It is about twenty lines and it removes a
dependency from the one part of the art pipeline that does not otherwise need
one.

WHAT THIS CANNOT KNOW
---------------------
A5 does not open .tres files, so the per-map palettes below are a MIRROR of
data/maps/<id>.tres, not a read of it. Same arrangement as art/preview_map.py's
placement constants, and the same rule applies: if the two ever disagree, the
.tres is correct and this table is stale. A map missing from PALETTES still
renders, in neutral greys, with a warning - a thumbnail that looks wrong is a
better failure than no thumbnail.

The durable fix is for Godot to generate these at runtime from MapDef plus the
layout, which would never go stale. That is a dozen lines of GDScript in the
level-select scene and it is A4's call; see art/PENDING.md.
"""

import os
import struct
import sys
import zlib

SIZE = 256
MARGIN = 6

ICON_DIR = "data/icons/maps"
MAP_DIR = "data/maps"

# Mirrors data/maps/<id>.tres ground_color / path_color / blocked_color.
# The .tres is correct; this is a copy. See the docstring.
PALETTES = {
    "crossing": {"ground": (0.29, 0.47, 0.26),
                 "path":   (0.62, 0.50, 0.34),
                 "blocked": (0.36, 0.38, 0.40)},
    "corridor": {"ground": (0.78, 0.60, 0.38),
                 "path":   (0.58, 0.42, 0.30),
                 "blocked": (0.46, 0.30, 0.22)},
}
DEFAULT_PALETTE = {"ground": (0.42, 0.44, 0.42),
                   "path": (0.62, 0.58, 0.50),
                   "blocked": (0.28, 0.29, 0.31)}

# game/board.gd:700-701 - the same two colours the in-game spawn and goal
# markers pulse in, so the thumbnail teaches the reading the board uses.
SPAWN = (1.00, 0.50, 0.20)
GOAL = (0.35, 0.95, 0.55)

# sim/grid.gd's legend, restated: . buildable  # path  X blocked  S spawn  G goal
LEGEND = {".": "ground", "#": "path", "X": "blocked", "S": "spawn", "G": "goal"}


def project_root():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(here, os.pardir))


def write_png(path, width, height, pixels):
    """Minimal RGBA PNG. `pixels` is a bytearray of width*height*4."""
    rows = bytearray()
    stride = width * 4
    for y in range(height):
        rows.append(0)                       # filter type 0 (None)
        rows.extend(pixels[y * stride:(y + 1) * stride])

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    blob = b"\x89PNG\r\n\x1a\n"
    blob += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    blob += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    blob += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(blob)


def srgb(colour, scale=1.0):
    return tuple(max(0, min(255, int(round(c * scale * 255.0)))) for c in colour)


def load_rows(path):
    with open(path, "r", encoding="utf-8") as handle:
        return [line.rstrip("\n").rstrip("\r")
                for line in handle.read().strip().split("\n") if line.strip()]


def render(map_id, rows):
    width_cells = max(len(r) for r in rows)
    height_cells = len(rows)
    usable = SIZE - MARGIN * 2
    cell = max(1, min(usable // width_cells, usable // height_cells))
    board_w = cell * width_cells
    board_h = cell * height_cells
    ox = (SIZE - board_w) // 2
    oy = (SIZE - board_h) // 2

    palette = PALETTES.get(map_id)
    if palette is None:
        print("  ! no palette for '%s' - rendering neutral. Add it to PALETTES." % map_id)
        palette = DEFAULT_PALETTE
    colours = {
        "ground": palette["ground"], "path": palette["path"],
        "blocked": palette["blocked"], "spawn": SPAWN, "goal": GOAL,
    }

    pixels = bytearray(SIZE * SIZE * 4)       # zeroed = fully transparent

    def put(x, y, rgb):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            i = (y * SIZE + x) * 4
            pixels[i:i + 4] = bytes((rgb[0], rgb[1], rgb[2], 255))

    for cy, row in enumerate(rows):
        for cx in range(width_cells):
            symbol = row[cx] if cx < len(row) else "X"
            kind = LEGEND.get(symbol, "blocked")
            base = colours[kind]
            # A one-pixel lighter top edge and darker bottom edge. At 10-12px a
            # cell that is one flat colour reads as a spreadsheet; this reads as
            # a stack of blocks, which is what the board actually is.
            body = srgb(base)
            top = srgb(base, 1.18)
            bottom = srgb(base, 0.78)
            for py in range(cell):
                shade = top if py == 0 else (bottom if py == cell - 1 else body)
                for px in range(cell):
                    put(ox + cx * cell + px, oy + cy * cell + py, shade)

    return pixels


def main():
    root = project_root()
    map_dir = os.path.join(root, MAP_DIR)
    layouts = sorted(f for f in os.listdir(map_dir) if f.endswith(".layout.txt"))
    if not layouts:
        print("no .layout.txt files under %s" % map_dir)
        return 1

    for name in layouts:
        map_id = name[:-len(".layout.txt")]
        rows = load_rows(os.path.join(map_dir, name))
        pixels = render(map_id, rows)
        out = os.path.join(root, ICON_DIR.replace("/", os.sep), "%s.png" % map_id)
        write_png(out, SIZE, SIZE, pixels)
        print("  [ ok ] %-12s %2dx%-2d -> %s" % (
            map_id, max(len(r) for r in rows), len(rows), os.path.relpath(out, root)))

    print("\n%d thumbnail(s) written to %s" % (len(layouts), ICON_DIR))
    return 0


if __name__ == "__main__":
    sys.exit(main())
