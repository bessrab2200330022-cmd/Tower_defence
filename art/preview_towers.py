"""Lay the whole tower ladder out at the RTS camera angle - three families by
four tiers - so the upgrade read can be judged comparatively.

The companion to preview_roster.py, and it exists for the same reason: a tier is
not a property of a model, it is a RELATION between models. "Does this read as
an upgrade" cannot be answered by looking at the upgrade. It can only be
answered next to the thing it upgrades from, and next to the sibling branch it
has to be distinguishable from.

Columns are tier 1, tier 2, tier 3A, tier 3B. Rows are the three families. Read
across a row for the ladder; read down a column to check that two families'
tier-3s do not collapse into each other at distance.

The rank bands (art/towers/_tier.py) are the thing to check hardest here: none,
one, two, left to right, in every row. If you cannot count them from this
distance they are not doing their job, and the tier read falls back to
silhouette alone.

Run:  blender -b --python art/preview_towers.py   (or Alt+P from the Text editor)
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "lib"))

import studio  # noqa: E402

FAMILIES = [
    ["arc_cannon", "arc_cannon_t2", "arc_cannon_t3a", "arc_cannon_t3b"],
    ["plasma_lance", "plasma_lance_t2", "plasma_lance_t3a", "plasma_lance_t3b"],
    ["frost_mortar", "frost_mortar_t2", "frost_mortar_t3a", "frost_mortar_t3b"],
]

# One grid cell is 2.0. Spacing a little wider so a swept barrel from one tower
# does not read as part of its neighbour - the Railshot in particular is 3.4
# deep and would otherwise look like it belongs to the tower behind it.
SPACING_X = 2.7
SPACING_Y = 4.0


# Mirrors what game/views/tower_view.gd does with TowerDef.body_color and
# accent_color. Reproduced here rather than read from data/towers/*.tres because
# A5 does not open .tres files - and because these are for LOOKING at, not for
# shipping. If they disagree with the .tres, the .tres is correct.
#
# Tinting the preview matters: in game a tier is read with colour helping, and
# judging nine silhouettes in flat grey is a harder test than the one the player
# actually sits. Both are worth doing - drop TINT to False for the grey pass.
TINT = True
PALETTE = {
    "arc_cannon":   {"body": (0.35, 0.65, 0.95), "accent": (0.95, 0.85, 0.45)},
    "plasma_lance": {"body": (0.55, 0.40, 0.90), "accent": (0.60, 0.95, 1.00)},
    "frost_mortar": {"body": (0.45, 0.80, 0.85), "accent": (0.90, 0.98, 1.00)},
}

# tower_view.gd's exact-match list today; A4 is moving the accent half to
# `Accent*` prefix matching this session (docs/ROUND-2.md). The preview honours
# BOTH, which is also how the models are named - see art/towers/_tier.py.
BODY_PARTS = ("Base", "Plinth", "TurretHead")
ACCENT_PARTS = ("AmmoDrum", "Sight", "Muzzle")


def _tint(root, family):
    if not TINT:
        return
    colours = PALETTE[family]
    body = studio.material("Body_%s" % family, colours["body"], metallic=0.3, roughness=0.5)
    accent = studio.material("Accent_%s" % family, colours["accent"],
                             metallic=0.5, roughness=0.35)
    for child in [root] + list(root.children_recursive):
        if child.type != "MESH":
            continue
        name = child.name.split(".")[0]
        pick = None
        if name in BODY_PARTS or name.startswith("Body"):
            pick = body
        elif name in ACCENT_PARTS or name.startswith("Accent"):
            pick = accent
        if pick is not None:
            child.data.materials.clear()
            child.data.materials.append(pick)


def _import(rel_path):
    path = os.path.join(studio.project_root(), rel_path.replace("/", os.sep))
    if not os.path.exists(path):
        print("missing", rel_path)
        return None
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    roots = [o for o in bpy.data.objects if o not in before and o.parent is None]
    return roots[0] if roots else None


def build():
    studio.reset_scene()

    width = (len(FAMILIES[0]) - 1) * SPACING_X
    depth = (len(FAMILIES) - 1) * SPACING_Y
    studio.box(
        "Ground", size=(width + 3.2, depth + 3.2, 0.12),
        location=(width * 0.5, depth * 0.5, -0.06),
        material=studio.material("Ground", (0.29, 0.47, 0.26), roughness=0.95),
    )

    placed = 0
    for row, family in enumerate(FAMILIES):
        for col, tower_id in enumerate(family):
            model = _import("data/models/towers/%s.glb" % tower_id)
            if model is None:
                continue
            model.location = (col * SPACING_X, row * SPACING_Y, 0.0)
            _tint(model, family[0])
            placed += 1

    studio.preview_lighting()
    print("tower ladder: %d of %d models" % (placed, sum(len(f) for f in FAMILIES)))
    return width, depth


if __name__ == "__main__" or __name__ == "__reload__":
    build()
