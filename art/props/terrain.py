"""Terrain kit - the chunky slabs the board is assembled from.

This is the single biggest lever on the art direction. The reference style is a
diorama: the ground is not a flat plane, it is thick blocks with visible side
walls, and the path sits lower than the grass so the board has depth even
before a single prop is placed.

Every block is modelled with its TOP FACE AT z = 0 and body hanging below, so
game/board.gd can place one at a cell centre without arithmetic. Bevels are
generous - they are what makes the edges catch light and stop the board reading
as untextured boxes.

Colour comes from MapDef in Godot (ground_color / path_color / blocked_color),
so one kit serves grassland, desert and snow. Materials here are preview only.

Output: data/models/terrain/*.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

CELL = studio.CELL_SIZE

VARIANTS = [
    # Grass slab: tall, so the side walls read as earth under turf.
    {"output": "data/models/terrain/ground_block.glb",
     "name": "GroundBlock", "depth": 1.1, "inset": 0.01, "bevel_width": 0.07},
    # Path slab: shallower, and inset slightly so a seam of shadow separates it
    # from the grass either side. That seam is what makes the route readable.
    {"output": "data/models/terrain/path_block.glb",
     "name": "PathBlock", "depth": 0.78, "inset": 0.04, "bevel_width": 0.05},
    # Border filler outside the play area. Chunkier bevel, no inset - it should
    # read as one continuous landmass, not as tiles.
    {"output": "data/models/terrain/border_block.glb",
     "name": "BorderBlock", "depth": 1.5, "inset": 0.0, "bevel_width": 0.1},
]


def build(name="GroundBlock", depth=1.1, inset=0.01, bevel_width=0.07):
    studio.reset_scene()
    stone = studio.material("Block", (0.35, 0.5, 0.32), metallic=0.0, roughness=0.9)

    root = studio.empty(name)
    width = CELL - inset * 2.0
    block = studio.box(
        "Block", size=(width, width, depth),
        parent=root, location=(0.0, 0.0, -depth * 0.5), material=stone,
    )
    studio.bevel(block, width=bevel_width, segments=1)
    return root


if __name__ == "__main__":
    for variant in VARIANTS:
        params = dict(variant)
        params.pop("output")
        model = build(**params)
        studio.export_glb(model, variant["output"])
    studio.preview_lighting()
