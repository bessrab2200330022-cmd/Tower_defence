"""Desert biome scatter kit for The Corridor - spires, sun-bleached wood, canyon rock.

Brief: docs/design/maps.md 4.6. "A dead river's slot canyon through mesa
country; the pads are ledges the canyon walls left behind."

THE BRIEF'S OWN SENTENCE IS THE DESIGN
--------------------------------------
"Height is the kit's real job. Blocked cells are four-fifths of this board and
they must read as WALLS, not floor - otherwise the corridor reads as a plain
with a brown road."

That rules out doing what the snow kit did. Snow could be a recolour plus four
new silhouettes because The Crossing's scenery lives on the border ring, where
its job is decoration. The Corridor's scenery is the level: the canyon IS the
blocked cells, and a kit of knee-high rocks scattered over them would leave the
player looking down into a trench that has no walls.

So the kit is led by the mesa spire, at 5.1 units the tallest asset in the
project by more than double the largest pine. Everything else in here is
support: the spire states the canyon, the rocks give its foot some rubble, and
the bleached pines put a sparse dead treeline on the rim so the mesa top reads
as a surface rather than as a cliff edge.

Two things the brief asks for that are NOT models and are recorded in
art/PENDING.md instead:

  * Terrain colour. Ground/path/blocked come from MapDef and corridor.tres
    already carries the brief's exact values - no geometry needed, same as snow.
  * "Scatter tall props on X." game/board.gd::_scatter_props() skips every
    in-bounds cell, so blocked cells inside the play area currently receive no
    props at all. That is a board.gd change, not an art one, and this kit is
    inert until it lands. See art/PENDING.md 1.

PLACEMENT CONSTRAINT, from the brief and worth repeating where a modeller will
see it: "keep spires a cell back from the path so silhouettes never occlude
enemies at the default camera pitch." A 5-unit spire beside the lane would hide
the wave. That is a rule for the scatter pass, not something geometry can fix -
but it is why the spire's footprint is kept narrow rather than made a boulder.

Props bake their own colour: board.gd::_scatter_props applies no material
override (unlike towers and terrain). Same as the grassland and snow kits.

Base at z = 0, and under ~1.6 across per nature.py - the spire is tall, not wide.

Output: data/models/props/*.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

VARIANTS = [
    {"output": "data/models/props/mesa_spire_large.glb",   "kind": "spire",   "size": 1.12},
    {"output": "data/models/props/mesa_spire_small.glb",   "kind": "spire",   "size": 0.74},
    {"output": "data/models/props/rock_desert_small.glb",  "kind": "rock",    "size": 0.55},
    {"output": "data/models/props/rock_desert_medium.glb", "kind": "rock",    "size": 0.90},
    {"output": "data/models/props/rock_desert_large.glb",  "kind": "rock",    "size": 1.35},
    {"output": "data/models/props/bush_dry.glb",           "kind": "scrub",   "size": 0.85},
    {"output": "data/models/props/pine_bleached_small.glb", "kind": "bleached", "size": 0.70},
    {"output": "data/models/props/pine_bleached_large.glb", "kind": "bleached", "size": 1.20},
]


def _palette():
    """Pitched against maps.md 4.6's terrain colours - ground (0.78, 0.60, 0.38),
    blocked (0.46, 0.30, 0.22) - so a spire standing on a blocked cell belongs to
    the wall it grows out of rather than sitting on top of it.

    Sandstone runs LIGHTER than the blocked colour on purpose. The brief warns
    the map must read at the MEDIUM quality step without SDFGI doing the canyon
    shadow, so the value separation between wall and spire has to be in the
    albedo, not borrowed from ambient occlusion that may not be running.
    """
    return {
        "stone": studio.material("Sandstone", (0.80, 0.62, 0.42), roughness=0.88),
        "strata": studio.material("Strata", (0.60, 0.42, 0.30), roughness=0.9),
        "shadow": studio.material("SandShadow", (0.52, 0.36, 0.26), roughness=0.92),
        # Sun-bleached, not dead-brown: driftwood grey with warmth left in it.
        "wood": studio.material("BleachedWood", (0.74, 0.68, 0.57), roughness=0.85),
        # Khaki-olive. The one non-sand hue in the kit, and deliberately dull -
        # maps.md flags the Scout Drone's orange against the river bed as the
        # collision to watch, so nothing here goes near orange.
        "scrub": studio.material("DryScrub", (0.52, 0.5, 0.3), roughness=0.9),
    }


def build(kind="spire", size=1.0):
    studio.reset_scene()
    mats = _palette()
    builders = {
        "spire": _spire,
        "rock": _rock,
        "scrub": _scrub,
        "bleached": _bleached_pine,
    }
    if kind not in builders:
        raise ValueError("unknown desert prop kind '%s'" % kind)
    return builders[kind](size, mats)


# ---------------------------------------------------------------------------

# radius, height, lift - four stacked drums, each narrower and set back a little
# from the one below. Total reach is 4.55 * size, so the large variant lands at
# roughly 5.1 units: two and a half grid cells, inside the brief's "2-3 blocks".
SPIRE_TIERS = [
    (0.60, 1.35, 0.00),
    (0.51, 1.30, 1.28),
    (0.41, 1.15, 2.50),
    (0.29, 0.95, 3.60),
]


def _spire(size, mats):
    """A mesa spire: stacked sedimentary drums with a strata band at each joint.

    Built as four separate prisms rather than one long taper because the joints
    are the whole point. A smooth cone reads as a termite mound; a stack of
    drums with a hard horizontal line between each reads as rock that was laid
    down and then cut, which is what mesa country looks like and what the "dead
    river cut this canyon" fiction needs.

    Low segment counts (7, then 6 as it narrows) keep it in the faceted
    low-poly family and stop the silhouette going smooth at the top, where it
    is most visible against sky.
    """
    root = studio.empty("MesaSpire")

    # Talus skirt. Rock does not meet ground at a clean line - it meets a pile
    # of what fell off it. Without this the spire reads as a post driven in.
    # 0.68, not the 0.82 first built: at 0.82 the large spire measured 1.785
    # across against nature.py's "under ~1.6 units wide so it does not crowd the
    # tile it sits on". The skirt is the widest thing on the model, so it is the
    # number that has to give - the spire's job is height, not footprint, and
    # the brief wants it a cell back from the lane anyway.
    skirt = studio.cylinder(
        "Talus", radius_bottom=0.68 * size, radius_top=0.56 * size,
        height=0.34 * size, segments=8,
        parent=root, material=mats["shadow"],
    )
    studio.bevel(skirt, width=0.03)

    for index, (radius, height, lift) in enumerate(SPIRE_TIERS):
        # Each drum steps back off-axis a little, alternating sides, so the
        # stack leans and counter-leans instead of standing like a chimney.
        offset = 0.055 * size * (1 if index % 2 else -1) * index
        drum = studio.cylinder(
            "Drum%d" % (index + 1),
            radius_bottom=radius * size, radius_top=radius * 0.86 * size,
            height=height * size, segments=7 if index < 2 else 6,
            parent=root, location=(offset, offset * 0.6, lift * size),
            material=mats["stone"],
        )
        drum.rotation_euler = (0.0, 0.0, index * 0.4)
        studio.bevel(drum, width=0.025)

        # The strata band: a slightly PROUD ring at the base of each drum. Proud
        # rather than recessed because at the RTS camera's downward angle a
        # recess is in shadow and disappears, while a lip catches the key light.
        band = studio.cylinder(
            "Strata%d" % (index + 1),
            radius_bottom=radius * 1.06 * size, radius_top=radius * 1.02 * size,
            height=0.11 * size, segments=7 if index < 2 else 6,
            parent=root, location=(offset, offset * 0.6, lift * size),
            material=mats["strata"],
        )
        band.rotation_euler = (0.0, 0.0, index * 0.4)
        studio.bevel(band, width=0.015)

    # A cap block, tilted. Mesas are flat-topped, and the tilt keeps the
    # skyline from being a perfect disc.
    cap = studio.cylinder(
        "Cap", radius_bottom=0.3 * size, radius_top=0.26 * size,
        height=0.22 * size, segments=6,
        parent=root, location=(0.02 * size, 0.0, 4.5 * size),
        material=mats["strata"],
    )
    cap.rotation_euler = (math.radians(4.0), math.radians(-3.0), 0.3)
    studio.bevel(cap, width=0.02)

    return root


def _rock(size, mats):
    """Canyon rubble. Same construction as nature.py::_rock so a desert board
    and a grassland board are recognisably the same game - only the stone
    colour and a flatter, more fractured proportion change."""
    root = studio.empty("DesertRock")

    body = studio.sphere(
        "Rock", radius=0.5 * size, subdivisions=1,
        parent=root, location=(0.0, 0.0, 0.3 * size), material=mats["stone"],
        scale=(1.1, 0.82, 0.62),      # flatter than the grassland rock: this is
    )                                  # spalled slab, not a glacial boulder
    body.rotation_euler = (0.14, 0.08, 0.9)
    studio.bevel(body, width=0.02)

    # A shadowed underslab, so the rock has a dark line under it even when the
    # renderer is not giving it contact shadow at the MEDIUM quality step.
    slab = studio.sphere(
        "RockBase", radius=0.42 * size, subdivisions=1,
        parent=root, location=(0.06 * size, -0.04 * size, 0.11 * size),
        material=mats["shadow"], scale=(1.2, 0.95, 0.34),
    )
    slab.rotation_euler = (0.0, 0.0, 0.5)

    if size > 0.6:
        chip = studio.sphere(
            "RockChip", radius=0.24 * size, subdivisions=1,
            parent=root, location=(0.5 * size, 0.22 * size, 0.13 * size),
            material=mats["stone"], scale=(1.0, 0.9, 0.62),
        )
        chip.rotation_euler = (0.4, 0.2, 1.1)
    return root


def _scrub(size, mats):
    """Dry brush. Sparser and spikier than the grassland bush - three small
    blobs instead of three large ones, plus bare twigs poking out of them.

    The twigs are what make it read as dead rather than as a bush someone
    forgot to water: a rounded silhouette reads as foliage at any colour."""
    root = studio.empty("DryBush")

    blobs = [(0.0, 0.0, 0.2, 1.0), (0.22, 0.13, 0.15, 0.66), (-0.19, -0.15, 0.13, 0.56)]
    for index, (x, y, z, scale) in enumerate(blobs):
        studio.sphere(
            "Scrub%d" % (index + 1), radius=0.24 * size * scale, subdivisions=1,
            parent=root, location=(x * size, y * size, z * size),
            material=mats["scrub"], scale=(1.0, 1.0, 0.72),
        )

    for index, (angle_deg, lean, length) in enumerate(
            ((25.0, 34.0, 0.46), (150.0, 28.0, 0.38), (265.0, 38.0, 0.42))):
        angle = math.radians(angle_deg)
        twig_length = length * size
        twig = studio.box(
            "Twig%d" % (index + 1), size=(twig_length, 0.035 * size, 0.03 * size),
            parent=root,
            location=(math.cos(angle) * twig_length * 0.4,
                      math.sin(angle) * twig_length * 0.4,
                      0.24 * size),
            material=mats["wood"],
        )
        twig.rotation_euler = (0.0, math.radians(-lean), angle)
    return root


def _bleached_pine(size, mats):
    """Sun-bleached dead pine for the mesa rim.

    Same trunk-and-limbs construction as snow.py::_pine_dead, which is
    deliberate - the two biomes should look like the same world in different
    climates, and a dead conifer is a dead conifer. What changes is the wood
    colour and the limb count: five instead of six, and shorter, because desert
    deadwood is picked apart by wind rather than weighed down by snow.
    """
    root = studio.empty("BleachedPine")

    trunk = studio.cylinder(
        "Trunk", radius_bottom=0.1 * size, radius_top=0.032 * size,
        height=1.5 * size, segments=6, parent=root, material=mats["wood"],
    )
    studio.bevel(trunk, width=0.012)

    limbs = [
        (30.0,  0.36, 0.5, 30.0),
        (140.0, 0.48, 0.44, 34.0),
        (250.0, 0.42, 0.46, 26.0),
        (85.0,  0.7,  0.34, 42.0),
        (210.0, 0.76, 0.3, 46.0),
    ]
    for index, (angle_deg, height_frac, length, lift_deg) in enumerate(limbs):
        angle = math.radians(angle_deg)
        limb_length = length * size
        limb = studio.box(
            "Limb%d" % (index + 1),
            size=(limb_length, 0.042 * size, 0.038 * size),
            parent=root,
            location=(math.cos(angle) * limb_length * 0.46,
                      math.sin(angle) * limb_length * 0.46,
                      height_frac * 1.5 * size),
            material=mats["wood"],
        )
        limb.rotation_euler = (0.0, math.radians(-lift_deg), angle)
        studio.bevel(limb, width=0.007)
    return root


if __name__ == "__main__":
    for variant in VARIANTS:
        params = dict(variant)
        params.pop("output")
        model = build(**params)
        studio.export_glb(model, variant["output"])
    studio.preview_lighting()
