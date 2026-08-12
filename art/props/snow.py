"""Snow biome scatter kit - drifts, dead pines, snow-laden pines, capped rocks.

EXPLORATORY. No snow map exists yet (BACKLOG 4). This is the kit a snow map
would need, built now so the map brief has something to be written against
rather than the other way round.

WHAT A SNOW BIOME ACTUALLY NEEDS, which is less than it sounds
--------------------------------------------------------------
No new terrain slabs. `art/props/terrain.py` builds them colourless and
`game/board.gd` applies `MapDef.ground_color` / `path_color` / `blocked_color`
as a material_override at line 146 - so a snow board is a new `.tres` with pale
colours, not new geometry. Building snow slabs would have produced three files
that duplicate three that already work.

No new ice crystal either. `nature.py::_crystal` is already documented as
"angular shards for the ice biome" and `crystal.glb` is already built. It is
not scattered by anything today (see art/PENDING.md) - wiring it is the whole
job.

So what is left is the four silhouettes the grassland kit genuinely cannot
supply, because winter changes shape and not just hue:

  * drifts     - the signature. Low, soft, wind-shaped mounds. Nothing in the
                 grassland kit is low and soft; rocks are hard and trees are
                 tall, and a board with only those two reads as "grassland,
                 recoloured".
  * dead pines - bare trunk and angled limbs. A completely different
                 silhouette from the grassland pine's three stacked cones,
                 which is the point: at RTS distance a recoloured cone is
                 still a cone.
  * snow pines - the same cones wearing snow, so the two tree types read as
                 one forest in one season rather than two unrelated props.
  * capped rocks - rock plus a settled cap, following the rock's own top.

PROPS BAKE THEIR OWN COLOUR
---------------------------
Unlike towers, scattered props are NOT tinted by Godot: `board.gd::_scatter_props`
instantiates and positions them and applies no material_override. The grassland
kit bakes its greens and browns for exactly this reason and this kit bakes its
whites the same way. (art/README.md's "models carry no colour" is a TOWER rule -
see art/PENDING.md.)

Snow is (0.88, 0.92, 0.97), not pure white. A flat 1.0 albedo under the board's
sun clips to a shape with no readable form at all, and the faint blue keeps it
sitting in the same cold palette as the Frost Mortar and the Shielded Scout.

Base at z = 0 and under ~1.6 units across, same as nature.py.

Output: data/models/props/*.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

VARIANTS = [
    {"output": "data/models/props/snow_drift_small.glb",  "kind": "drift",     "size": 0.7},
    # 1.18, not 1.25: at 1.25 the drift measured 1.628 across and nature.py's
    # own rule is "under ~1.6 units wide so it does not crowd the tile it sits
    # on". Drifts are the widest thing in this kit by design, so this one sits
    # closest to the ceiling and is the one that has to be watched.
    {"output": "data/models/props/snow_drift_large.glb",  "kind": "drift",     "size": 1.18},
    {"output": "data/models/props/pine_dead_small.glb",   "kind": "pine_dead", "size": 0.7},
    {"output": "data/models/props/pine_dead_large.glb",   "kind": "pine_dead", "size": 1.3},
    {"output": "data/models/props/pine_snow_medium.glb",  "kind": "pine_snow", "size": 1.0},
    {"output": "data/models/props/pine_snow_large.glb",   "kind": "pine_snow", "size": 1.42},
    {"output": "data/models/props/rock_snow_medium.glb",  "kind": "rock_snow", "size": 0.9},
    {"output": "data/models/props/rock_snow_large.glb",   "kind": "rock_snow", "size": 1.35},
]


def _palette():
    return {
        "snow": studio.material("Snow", (0.88, 0.92, 0.97), roughness=0.72),
        # Colder and greyer than nature.py's bark (0.32, 0.22, 0.15). Dead wood
        # in snow goes silver, not brown.
        "bark": studio.material("DeadBark", (0.29, 0.26, 0.25), roughness=0.88),
        # Darker and less saturated than the grassland needle (0.16, 0.42, 0.24).
        # Winter conifers read almost black against snow, and that contrast is
        # what makes the drifts look bright without blowing the albedo out.
        "needle": studio.material("WinterNeedle", (0.13, 0.28, 0.23), roughness=0.82),
        # Bluer than the grassland stone (0.46, 0.47, 0.5).
        "stone": studio.material("ColdStone", (0.41, 0.45, 0.53), roughness=0.9),
    }


def build(kind="drift", size=1.0):
    studio.reset_scene()
    mats = _palette()
    builders = {
        "drift": _drift,
        "pine_dead": _pine_dead,
        "pine_snow": _pine_snow,
        "rock_snow": _rock_snow,
    }
    if kind not in builders:
        raise ValueError("unknown snow prop kind '%s'" % kind)
    return builders[kind](size, mats)


# ---------------------------------------------------------------------------

def _drift(size, mats):
    """A wind-shaped mound. Three overlapping flattened icospheres, decreasing
    along one axis so the drift has a windward and a leeward end.

    The asymmetry is the whole trick. A symmetrical mound reads as a dome, and
    a dome reads as a rock. Scatter rotates each prop randomly, so a directional
    drift also gives the border a sense of weather rather than of decoration.
    """
    root = studio.empty("SnowDrift")

    lobes = [
        # x,     y,     z,     scale, flatten
        # z is set so the drift embeds by roughly the same amount as the shipped
        # rocks (-0.04) and no more. A drift SHOULD sit into the ground rather
        # than on it - a visible flat underside reads as a dropped object - but
        # the relief bump above sank the large one to -0.105 before this.
        (0.0,   0.0,   0.21,  1.0,   0.52),
        (0.42,  0.12,  0.16,  0.68,  0.44),
        (-0.34, -0.10, 0.14,  0.55,  0.38),
    ]
    for index, (x, y, z, scale, flatten) in enumerate(lobes):
        lobe = studio.sphere(
            "Drift%d" % (index + 1), radius=0.46 * size * scale, subdivisions=1,
            parent=root,
            location=(x * size, y * size, z * size),
            material=mats["snow"],
            scale=(1.25, 1.0, flatten),
        )
        lobe.rotation_euler = (0.0, 0.0, index * 0.5)
        studio.bevel(lobe, width=0.02)
    return root


def _pine_dead(size, mats):
    """Bare trunk and angled limbs. Shorter than a living pine on purpose -
    a dead conifer has lost its crown, and the missing top is most of what
    tells you it is dead from a long way off."""
    root = studio.empty("DeadPine")

    trunk = studio.cylinder(
        "Trunk", radius_bottom=0.11 * size, radius_top=0.035 * size,
        height=1.55 * size, segments=6, parent=root, material=mats["bark"],
    )
    studio.bevel(trunk, width=0.012)

    # Limbs spiralling up the trunk. Angles are deliberately not evenly spaced:
    # an even spiral reads as a machined part, which is the towers' language.
    limbs = [
        # angle_deg, height_frac, length, lift_deg
        (20.0,  0.34, 0.62, 26.0),
        (128.0, 0.46, 0.54, 32.0),
        (238.0, 0.40, 0.58, 22.0),
        (72.0,  0.68, 0.44, 38.0),
        (196.0, 0.74, 0.40, 42.0),
        (306.0, 0.60, 0.48, 30.0),
    ]
    for index, (angle_deg, height_frac, length, lift_deg) in enumerate(limbs):
        angle = math.radians(angle_deg)
        limb_length = length * size
        limb = studio.box(
            "Limb%d" % (index + 1),
            size=(limb_length, 0.05 * size, 0.045 * size),
            parent=root,
            location=(math.cos(angle) * limb_length * 0.46,
                      math.sin(angle) * limb_length * 0.46,
                      height_frac * 1.55 * size),
            material=mats["bark"],
        )
        # Y first, then Z, under Blender's XYZ euler order: tilt the outer end
        # up, then swing the whole limb round the trunk.
        limb.rotation_euler = (0.0, math.radians(-lift_deg), angle)
        studio.bevel(limb, width=0.008)

    # A little settled snow on the two highest limbs, so a dead pine still
    # belongs to the same weather as everything around it.
    for index, (angle_deg, height_frac) in enumerate(((72.0, 0.68), (196.0, 0.74))):
        angle = math.radians(angle_deg)
        studio.sphere(
            "LimbSnow%d" % (index + 1), radius=0.11 * size, subdivisions=1,
            parent=root,
            location=(math.cos(angle) * 0.22 * size,
                      math.sin(angle) * 0.22 * size,
                      height_frac * 1.55 * size + 0.09 * size),
            material=mats["snow"],
            scale=(1.5, 1.0, 0.42),
        )
    return root


def _pine_snow(size, mats):
    """The grassland pine's three-tier cone, in winter dress.

    Tier geometry is copied from nature.py::_pine rather than reinvented: these
    two trees must read as the same species in different seasons, and matching
    the tier table is what guarantees that. If nature.py's tiers ever change,
    change these with them.
    """
    root = studio.empty("SnowPine")

    trunk = studio.cylinder(
        "Trunk", radius_bottom=0.12 * size, radius_top=0.09 * size,
        height=0.5 * size, segments=6, parent=root, material=mats["bark"],
    )
    studio.bevel(trunk, width=0.01)

    tiers = [(0.62, 0.95, 0.30), (0.48, 0.80, 0.72), (0.32, 0.62, 1.12)]
    for index, (radius, height, lift) in enumerate(tiers):
        cone = studio.cylinder(
            "Foliage%d" % (index + 1),
            radius_bottom=radius * size, radius_top=0.02 * size,
            height=height * size, segments=7,
            parent=root, location=(0.0, 0.0, lift * size), material=mats["needle"],
        )
        studio.bevel(cone, width=0.015)

        # Snow load on the branch layer, sitting on the LOWER shoulder of each
        # tier where a real conifer catches it - not a cap on the point.
        #
        # The taper is the whole trick and it is easy to get backwards. The
        # tier's own cone loses a full radius over its height; this collar has
        # to lose LESS than that over the span it covers, or it sits inside the
        # green and renders as nothing. Dropping r -> 0.85r across 0.30h leaves
        # it standing 0.15r proud at the top of the collar, which is the white
        # flare you actually see. The first attempt tapered faster than the
        # tier and was invisible on every tier but the topmost.
        #
        # radius_bottom is exactly the tier radius, never more: that keeps
        # pine_snow_large the same width as pine_large, which is what makes the
        # two read as one species in two seasons.
        collar = studio.cylinder(
            "Snow%d" % (index + 1),
            radius_bottom=radius * size, radius_top=radius * 0.85 * size,
            height=height * 0.3 * size, segments=7,
            parent=root, location=(0.0, 0.0, lift * size),
            material=mats["snow"],
        )
        # Bevelled to the same width as the tier it sits on. This is not
        # decoration: bevelling shaves the profile slightly, so an unbevelled
        # collar on a bevelled cone measured 0.023 PROUD of the grassland
        # pine's silhouette. Matching the treatment matches the width.
        studio.bevel(collar, width=0.015)

    # Cap on the apex, so the tree still ends in white from directly above.
    top_radius, top_height, top_lift = tiers[-1]
    studio.cylinder(
        "SnowCap",
        radius_bottom=top_radius * 0.5 * size, radius_top=0.02 * size,
        height=top_height * 0.5 * size, segments=7,
        parent=root,
        location=(0.0, 0.0, (top_lift + top_height * 0.5) * size),
        material=mats["snow"],
    )
    return root


def _rock_snow(size, mats):
    """nature.py's rock with a cap settled on its upper surface.

    The cap is a separate flattened blob rather than a recolour of the rock's
    top faces, because low-poly rocks have four or five faces up there and
    painting some of them white reads as a texture error. A distinct mass
    reads as snow.
    """
    root = studio.empty("SnowRock")

    body = studio.sphere(
        "Rock", radius=0.5 * size, subdivisions=1,
        parent=root, location=(0.0, 0.0, 0.32 * size), material=mats["stone"],
        scale=(1.0, 0.85, 0.72),
    )
    body.rotation_euler = (0.18, 0.1, 0.6)
    studio.bevel(body, width=0.02)

    cap = studio.sphere(
        "RockSnow", radius=0.44 * size, subdivisions=1,
        parent=root, location=(0.0, 0.02 * size, 0.5 * size),
        material=mats["snow"], scale=(1.06, 0.92, 0.4),
    )
    cap.rotation_euler = (0.1, 0.06, 0.6)
    studio.bevel(cap, width=0.015)

    if size > 0.6:
        chip = studio.sphere(
            "RockChip", radius=0.24 * size, subdivisions=1,
            parent=root, location=(0.46 * size, 0.2 * size, 0.14 * size),
            material=mats["stone"], scale=(1.0, 0.9, 0.7),
        )
        chip.rotation_euler = (0.4, 0.2, 1.1)

        studio.sphere(
            "ChipSnow", radius=0.2 * size, subdivisions=1,
            parent=root, location=(0.46 * size, 0.2 * size, 0.24 * size),
            material=mats["snow"], scale=(1.05, 0.95, 0.34),
        )
    return root


if __name__ == "__main__":
    for variant in VARIANTS:
        params = dict(variant)
        params.pop("output")
        model = build(**params)
        studio.export_glb(model, variant["output"])
    studio.preview_lighting()
