"""Assemble a map preview in Blender, mirroring game/board.gd.

This builds nothing that ships. It exists so the board can be looked at without
launching Godot, which matters when the person reviewing the art and the person
running the engine are not in the same place.

It deliberately reimplements the placement rules from game/board.gd rather than
sharing them - they are twenty lines, and the alternative is a Python/GDScript
bridge that would be far more code than it saves. If the two ever disagree,
game/board.gd is correct and this file is wrong.

Run:  blender -b --python art/preview_map.py     (or Alt+P from the Text editor)
"""

import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "lib"))

import studio  # noqa: E402

MAP_ID = "crossing"
CELL = studio.CELL_SIZE

# Must match the constants at the top of game/board.gd.
BORDER_WIDTH = 4
GROUND_TOP = 0.0
PATH_TOP = -0.22
BORDER_TOP = -0.1
PROP_CHANCE = 0.62

GROUND_COLOR = (0.28, 0.46, 0.26)
PATH_COLOR = (0.55, 0.44, 0.3)
BORDER_COLOR = (0.2, 0.34, 0.2)


def _root():
    return studio.project_root()


def _load_layout():
    path = os.path.join(_root(), "data", "maps", "%s.layout.txt" % MAP_ID)
    with open(path, "r", encoding="utf-8") as handle:
        rows = [line.strip() for line in handle.read().strip().split("\n") if line.strip()]
    return rows


def _import(rel_path):
    """Import a .glb and return its root object, or None."""
    path = os.path.join(_root(), rel_path.replace("/", os.sep))
    if not os.path.exists(path):
        print("missing", rel_path)
        return None
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new_roots = [o for o in bpy.data.objects if o not in before and o.parent is None]
    return new_roots[0] if new_roots else None


def _tint(obj, color):
    material = studio.material("Tint_%s" % obj.name, color, roughness=0.9)
    for child in [obj] + list(obj.children_recursive):
        if child.type != "MESH":
            continue
        child.data.materials.clear()
        child.data.materials.append(material)


def _place(template, location, rotation_z=0.0, scale=1.0):
    """Linked duplicate - shares mesh data, so 500 blocks cost one mesh."""
    copy = template.copy()
    if template.data is not None:
        copy.data = template.data
    bpy.context.collection.objects.link(copy)
    for child in template.children:
        child_copy = child.copy()
        child_copy.data = child.data
        child_copy.parent = copy
        bpy.context.collection.objects.link(child_copy)
    copy.location = location
    copy.rotation_euler = (0.0, 0.0, rotation_z)
    copy.scale = (scale, scale, scale)
    return copy


def build():
    studio.reset_scene()
    rows = _load_layout()
    height = len(rows)
    width = len(rows[0])
    print("map %s: %dx%d" % (MAP_ID, width, height))

    ground_tpl = _import("data/models/terrain/ground_block.glb")
    path_tpl = _import("data/models/terrain/path_block.glb")
    border_tpl = _import("data/models/terrain/border_block.glb")
    if ground_tpl is None or path_tpl is None:
        raise RuntimeError("terrain kit missing - run art/props/terrain.py first")

    _tint(ground_tpl, GROUND_COLOR)
    _tint(path_tpl, PATH_COLOR)
    if border_tpl is not None:
        _tint(border_tpl, BORDER_COLOR)

    # Templates live off-screen; only their duplicates are positioned.
    for template in (ground_tpl, path_tpl, border_tpl):
        if template is not None:
            template.location = (0.0, 0.0, -500.0)

    def cell_world(x, y):
        return ((x + 0.5) * CELL, (y + 0.5) * CELL)

    def is_path(x, y):
        if x < 0 or y < 0 or x >= width or y >= height:
            return False
        return rows[y][x] in "#SG"

    def is_buildable(x, y):
        if x < 0 or y < 0 or x >= width or y >= height:
            return False
        return rows[y][x] == "."

    # --- terrain --------------------------------------------------------
    for y in range(height):
        for x in range(width):
            wx, wy = cell_world(x, y)
            if is_path(x, y):
                _place(path_tpl, (wx, wy, PATH_TOP))
            else:
                _place(ground_tpl, (wx, wy, GROUND_TOP))

    # --- border ---------------------------------------------------------
    rng = random.Random(1234)
    props = []
    for rel in ["pine_large", "pine_medium", "pine_small",
                "rock_medium", "rock_small", "rock_large", "bush"]:
        template = _import("data/models/props/%s.glb" % rel)
        if template is not None:
            template.location = (0.0, 0.0, -500.0)
            props.append(template)
    weights = [26, 30, 18, 12, 8, 4, 12][:len(props)]

    for y in range(-BORDER_WIDTH, height + BORDER_WIDTH):
        for x in range(-BORDER_WIDTH, width + BORDER_WIDTH):
            if 0 <= x < width and 0 <= y < height:
                continue
            distance = max(max(-x, x - width + 1), max(-y, y - height + 1))
            drop = distance * 0.34 + rng.randint(0, 3) * 0.11
            wx, wy = cell_world(x, y)
            if border_tpl is not None:
                _place(border_tpl, (wx, wy, BORDER_TOP - drop))
            if props and rng.random() < PROP_CHANCE:
                template = rng.choices(props, weights=weights)[0]
                _place(
                    template,
                    (wx + rng.uniform(-0.4, 0.4) * CELL,
                     wy + rng.uniform(-0.4, 0.4) * CELL,
                     BORDER_TOP - distance * 0.34),
                    rotation_z=rng.uniform(0.0, math.tau),
                    scale=rng.uniform(0.82, 1.27),
                )

    # Placement pads were removed from the game - they covered most of a board
    # whose corridors run one cell apart and read as tiling. See art/props/pad.py.

    # --- a few towers and enemies, so scale reads --------------------------
    for tower, (cx, cy) in [("arc_cannon", (2, 2)), ("plasma_lance", (16, 5)),
                            ("frost_mortar", (5, 8)), ("arc_cannon", (12, 3))]:
        template = _import("data/models/towers/%s.glb" % tower)
        if template is None:
            continue
        wx, wy = cell_world(cx, cy)
        template.location = (wx, wy, GROUND_TOP)
        template.rotation_euler = (0.0, 0.0, rng.uniform(0.0, math.tau))

    for enemy, (cx, cy) in [("walker", (6, 1)), ("drone", (9, 1)),
                            ("brute", (18, 4)), ("shielded_scout", (3, 7))]:
        template = _import("data/models/enemies/%s.glb" % enemy)
        if template is None:
            continue
        wx, wy = cell_world(cx, cy)
        template.location = (wx, wy, PATH_TOP)

    studio.preview_lighting()
    centre_x = width * CELL * 0.5
    centre_y = height * CELL * 0.5
    studio.preview_viewport(
        target=(centre_x, centre_y, 0.0),
        distance=max(width, height) * CELL * 1.15,
        azimuth_deg=18.0, elevation_deg=42.0,
    )
    print("preview built: %d objects" % len(bpy.data.objects))


if __name__ == "__main__" or __name__ == "__reload__":
    build()
