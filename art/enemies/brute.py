"""Siege Brute - slow, heavily armoured, costs 2 lives if it lands.

The player needs to see this coming from across the map and reach for the
Plasma Lance. So it is the only enemy that is wider than it is tall, the only
one with layered armour plates, and the only one whose silhouette overlaps its
neighbours in a spawn group. Bulk is the entire brief.

Output: data/models/enemies/brute.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/enemies/brute.glb"

RADIUS = 0.7
HEIGHT = 1.7


def build():
    studio.reset_scene()

    shell = studio.material("Shell", (0.55, 0.25, 0.3), metallic=0.35, roughness=0.55)
    glow = studio.material("Glow", (1.0, 0.55, 0.3), emission=1.5, roughness=0.3)
    dark = studio.material("Dark", (0.17, 0.1, 0.12), metallic=0.4, roughness=0.55)

    root = studio.empty("Brute")

    # Treads rather than legs. Slow is the read, and nothing says slow like
    # something that grinds along the ground.
    tread = studio.box(
        "Tread", size=(0.34, 1.2, 0.42),
        parent=root, location=(0.52, 0.0, 0.21), material=dark,
    )
    studio.mirror_x(tread, about=root)
    studio.bevel(tread, width=0.03, segments=2)

    # Hull: a heavy hexagonal slab. The first pass topped out at 1.16 units -
    # shorter than the Walker - which inverted the whole point of the enemy.
    # It has to be visibly the biggest thing on the board.
    hull = studio.cylinder(
        "Body", radius_bottom=RADIUS, radius_top=RADIUS * 0.82,
        height=HEIGHT * 0.62, segments=6,
        parent=root, location=(0.0, 0.0, HEIGHT * 0.22), material=shell,
    )
    hull.rotation_euler = (0.0, 0.0, math.radians(30.0))
    studio.bevel(hull, width=0.035, segments=2)

    # Layered glacis plate on the front. The overlap is what makes it read as
    # armour rather than as a big lump.
    for index, (depth, lift, width) in enumerate(
            [(0.16, 0.28, 0.95), (0.14, 0.66, 0.84), (0.12, 1.02, 0.66)]):
        plate = studio.box(
            "Plate%d" % (index + 1), size=(width, depth, 0.26),
            parent=hull, location=(0.0, -RADIUS * 0.86, lift - HEIGHT * 0.22),
            material=dark,
        )
        plate.rotation_euler = (math.radians(-18.0), 0.0, 0.0)
        studio.bevel(plate, width=0.015)

    # Dorsal spine with vents, giving it a top-down read as well as a side one -
    # from the RTS camera you see more of the top of this thing than its face.
    spine = studio.box(
        "Spine", size=(0.34, 0.9, 0.3),
        parent=hull, location=(0.0, 0.12, HEIGHT * 0.6), material=shell,
    )
    studio.bevel(spine, width=0.02)

    vent = studio.box(
        "Vent", size=(0.1, 0.6, 0.1),
        parent=spine, location=(0.2, 0.0, 0.12), material=glow,
    )
    studio.mirror_x(vent, about=spine)

    # Two eyes, low and wide set.
    eye = studio.sphere(
        "Eye", radius=0.11, subdivisions=1,
        parent=hull, location=(0.26, -RADIUS * 0.9, HEIGHT * 0.06),
        material=glow, scale=(1.0, 0.6, 0.8),
    )
    studio.mirror_x(eye, about=hull)

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
