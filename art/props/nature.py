"""Scatter props - trees, rocks, bushes, crystals.

These do nothing mechanically. Their entire job is to make the board look like
a place rather than a grid, which is most of the difference between the current
game and the reference screenshots.

Two rules that matter more than the modelling:

  * Props go OUTSIDE the play area, or on blocked cells. A tree on a buildable
    cell is a lie - the player can build there, and the art says they cannot.
  * They are scattered from a seeded RNG in game/board.gd, not placed by hand,
    so a new map gets dressed automatically.

Each prop is built with its base at z = 0 and stays under ~1.6 units wide so it
does not crowd the tile it sits on.

Output: data/models/props/*.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

VARIANTS = [
    {"output": "data/models/props/pine_small.glb",  "kind": "pine",    "size": 0.62},
    {"output": "data/models/props/pine_medium.glb", "kind": "pine",    "size": 1.0},
    {"output": "data/models/props/pine_large.glb",  "kind": "pine",    "size": 1.42},
    {"output": "data/models/props/rock_small.glb",  "kind": "rock",    "size": 0.55},
    {"output": "data/models/props/rock_medium.glb", "kind": "rock",    "size": 0.9},
    {"output": "data/models/props/rock_large.glb",  "kind": "rock",    "size": 1.35},
    {"output": "data/models/props/bush.glb",        "kind": "bush",    "size": 0.8},
    {"output": "data/models/props/crystal.glb",     "kind": "crystal", "size": 1.0},
]


def build(kind="pine", size=1.0):
    studio.reset_scene()
    builders = {
        "pine": _pine,
        "rock": _rock,
        "bush": _bush,
        "crystal": _crystal,
    }
    if kind not in builders:
        raise ValueError("unknown prop kind '%s'" % kind)
    return builders[kind](size)


# ---------------------------------------------------------------------------

def _pine(size):
    """Stacked cones on a short trunk. Three tiers rather than one so the
    silhouette has steps in it - a single cone reads as a traffic cone."""
    bark = studio.material("Bark", (0.32, 0.22, 0.15), roughness=0.85)
    needle = studio.material("Needle", (0.16, 0.42, 0.24), roughness=0.8)

    root = studio.empty("PineTree")

    trunk = studio.cylinder(
        "Trunk", radius_bottom=0.12 * size, radius_top=0.09 * size,
        height=0.5 * size, segments=6, parent=root, material=bark,
    )
    studio.bevel(trunk, width=0.01)

    # Each tier narrower and shorter than the one below. The overlap is what
    # makes it read as foliage rather than as three separate cones.
    tiers = [(0.62, 0.95, 0.30), (0.48, 0.80, 0.72), (0.32, 0.62, 1.12)]
    for index, (radius, height, lift) in enumerate(tiers):
        cone = studio.cylinder(
            "Foliage%d" % (index + 1),
            radius_bottom=radius * size, radius_top=0.02 * size,
            height=height * size, segments=7,
            parent=root, location=(0.0, 0.0, lift * size), material=needle,
        )
        studio.bevel(cone, width=0.015)
    return root


def _rock(size):
    """A squashed low-subdivision icosphere. Rotated off-axis so a scattered
    field of them does not read as a row of identical pebbles."""
    stone = studio.material("Stone", (0.46, 0.47, 0.5), roughness=0.9)

    root = studio.empty("Rock")
    body = studio.sphere(
        "Rock", radius=0.5 * size, subdivisions=1,
        parent=root, location=(0.0, 0.0, 0.32 * size), material=stone,
        scale=(1.0, 0.85, 0.72),
    )
    body.rotation_euler = (0.18, 0.1, 0.6)
    studio.bevel(body, width=0.02)

    # A smaller companion. Rocks in the reference are always clustered, never
    # solitary, and a pair costs one extra primitive.
    if size > 0.6:
        chip = studio.sphere(
            "RockChip", radius=0.24 * size, subdivisions=1,
            parent=root, location=(0.46 * size, 0.2 * size, 0.14 * size),
            material=stone, scale=(1.0, 0.9, 0.7),
        )
        chip.rotation_euler = (0.4, 0.2, 1.1)
    return root


def _bush(size):
    """Three overlapping blobs. Cheap, and the clustering reads as foliage."""
    leaf = studio.material("Leaf", (0.24, 0.5, 0.26), roughness=0.85)

    root = studio.empty("Bush")
    blobs = [(0.0, 0.0, 0.26, 1.0), (0.24, 0.14, 0.2, 0.72), (-0.2, -0.16, 0.18, 0.62)]
    for index, (x, y, z, scale) in enumerate(blobs):
        studio.sphere(
            "Bush%d" % (index + 1), radius=0.3 * size * scale, subdivisions=1,
            parent=root, location=(x * size, y * size, z * size),
            material=leaf, scale=(1.0, 1.0, 0.8),
        )
    return root


def _crystal(size):
    """Angular shards for the ice biome, and a decent generic 'this tile is
    special' marker. Tapered hexagonal spikes at varying lean."""
    ice = studio.material("Ice", (0.42, 0.76, 0.95), roughness=0.2, emission=0.6)

    root = studio.empty("Crystal")
    shards = [
        (0.0, 0.0, 1.0, 0.0, 0.0),
        (0.26, 0.1, 0.62, 0.22, 0.4),
        (-0.22, -0.14, 0.48, -0.26, -0.3),
    ]
    for index, (x, y, height, tilt_x, tilt_y) in enumerate(shards):
        shard = studio.cylinder(
            "Shard%d" % (index + 1),
            radius_bottom=0.16 * size * height, radius_top=0.02,
            height=height * size, segments=6,
            parent=root, location=(x * size, y * size, 0.0), material=ice,
        )
        shard.rotation_euler = (tilt_x, tilt_y, index * 0.7)
        studio.bevel(shard, width=0.01)
    return root


if __name__ == "__main__":
    for variant in VARIANTS:
        params = dict(variant)
        params.pop("output")
        model = build(**params)
        studio.export_glb(model, variant["output"])
    studio.preview_lighting()
