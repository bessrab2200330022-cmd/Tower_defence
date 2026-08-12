"""RETIRED - tower placement pad. Nothing in the game references this any more.

Kept because the model is fine and the idea may come back for an "upgradeable
slot" feature; the reason it was dropped is that pads on a board whose corridors
run one cell apart cover most of the map and read as tiling, and thinning them
with a parity rule made the placement look arbitrary rather than designed.

Safe to delete this file and data/models/terrain/pad.glb.

--- original notes ---

Tower placement pad - the octagonal stone platform towers are built on.

In the reference screenshots the pads do a lot of quiet work: they tell you
where you may build before you have selected anything, and they make a tower
look installed rather than dropped. Ours pull the same weight, and because the
sim already knows which cells are buildable, game/board.gd can place them
without any new data.

Top face at z = 0 like the terrain blocks, so it drops onto a cell centre.
Rim is a separate mesh named "Rim" so Godot can tint it per state (available,
occupied, blocked) without needing four different models.

Output: data/models/terrain/pad.glb
"""

import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/terrain/pad.glb"

RADIUS = 0.82


def build():
    studio.reset_scene()
    stone = studio.material("PadStone", (0.62, 0.62, 0.6), roughness=0.75)
    rim = studio.material("PadRim", (0.5, 0.75, 0.9), roughness=0.4, emission=0.5)

    root = studio.empty("Pad")

    # Body sunk below z = 0 so only the top plate and rim sit above the tile.
    body = studio.prism(
        "PadBody", radius=RADIUS, height=0.34, segments=8,
        parent=root, location=(0.0, 0.0, -0.34), material=stone,
    )
    studio.bevel(body, width=0.04)

    # Inner plate, very slightly proud. The step catches a highlight and reads
    # as machined rather than as a flat disc.
    plate = studio.prism(
        "PadPlate", radius=RADIUS * 0.74, height=0.06, segments=8,
        parent=root, location=(0.0, 0.0, -0.03), material=stone,
    )
    studio.bevel(plate, width=0.02)

    # Rim ring. Separate mesh, separate name - this is the bit Godot recolours
    # to signal state, so it must not be merged into the body.
    ring = studio.cylinder(
        "Rim", radius_bottom=RADIUS * 0.94, radius_top=RADIUS * 0.94,
        height=0.05, segments=8,
        parent=root, location=(0.0, 0.0, -0.02), material=rim,
    )
    studio.bevel(ring, width=0.012)

    # Four corner studs, so the octagon has a front and reads as constructed.
    for index, angle in enumerate([0.7854, 2.3562, 3.927, 5.4978]):
        import math
        stud = studio.box(
            "Stud%d" % (index + 1), size=(0.16, 0.16, 0.12),
            parent=root,
            location=(math.cos(angle) * RADIUS * 0.8,
                      math.sin(angle) * RADIUS * 0.8, -0.02),
            material=stone,
        )
        stud.rotation_euler = (0.0, 0.0, angle)
        studio.bevel(stud, width=0.015)

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
