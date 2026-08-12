"""Focused Array - Plasma Lance tier 2.

voice.md: "Recollimated emitters drive the beam harder and further. Three shots
drop a shielded scout." upgrades.md 5: 560 damage, 60 ticks, range 13 -> 14.

The base Lance is a hexagonal pylon with THREE glowing capacitor rods running up
its shaft, and those rods are the family's signature - they are why an idle Lance
with a 1.1-second reload still looks charged rather than broken. Tier 2 is that
idea, denser: FIVE rods, a thicker pylon to carry them, a second collar at the
mount, and a longer emitter.

Counting rods is the same trick as counting the Arc family's feed drums. Within
a family, tier 2 should be countable, not just bigger - "bigger" is ambiguous at
distance when the towers around it are at different tiers too.

Node contract: Base / Turret / Barrel, as ever. The pylon is named Plinth
because tower_view.gd tints BODY_PARTS by that exact name - it was called Pylon
once and the whole shaft went untinted for a release.

Output: data/models/towers/plasma_lance_t2.glb
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, os.pardir, "lib"))
sys.path.insert(0, _HERE)

import studio  # noqa: E402
import _tier  # noqa: E402

OUTPUT_PATH = "data/models/towers/plasma_lance_t2.glb"

PYLON_HEIGHT = 1.35
BARREL_LENGTH = 1.75
TURRET_Z = 1.80
ROD_COUNT = 5


def build():
    studio.reset_scene()
    mats = _tier.materials()

    root = studio.empty("PlasmaLanceT2")

    pad = studio.cylinder(
        "Base", radius_bottom=0.74, radius_top=0.7, height=0.19, segments=6,
        parent=root, material=mats["dark"],
    )
    studio.bevel(pad, width=0.02)

    plinth = studio.cylinder(
        "Plinth", radius_bottom=0.5, radius_top=0.3,
        height=PYLON_HEIGHT, segments=6,
        parent=pad, location=(0.0, 0.0, 0.17), material=mats["hull"],
    )
    studio.bevel(plinth, width=0.025)

    _tier.rank_bands(plinth, 1, radius=0.42, base_z=PYLON_HEIGHT * 0.34,
                     material=mats["accent"])

    # Five rods around the shaft. radial() rather than a mirrored pair because
    # an odd count has no flat side - the shaft looks charged from every angle
    # the camera can reach, which a mirrored pair does not.
    for index, x, y, _angle in _tier.radial(ROD_COUNT, 0.38, start_deg=90.0):
        rod = studio.box(
            "AccentRod%d" % (index + 1),
            size=(0.09, 0.09, PYLON_HEIGHT * 0.58),
            parent=plinth, location=(x, y, PYLON_HEIGHT * 0.46),
            material=mats["glow"],
        )
        studio.bevel(rod, width=0.01)

    collar = studio.cylinder(
        "Collar", radius_bottom=0.28, radius_top=0.34, height=0.3, segments=12,
        parent=plinth, location=(0.0, 0.0, PYLON_HEIGHT), material=mats["dark"],
    )
    studio.bevel(collar, width=0.02)

    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_Z))

    head = studio.wedge(
        "TurretHead", size=(0.7, 0.82, 0.52),
        parent=turret, material=mats["hull"], taper=0.55,
    )
    studio.bevel(head, width=0.025)

    tail = studio.box(
        "Counterweight", size=(0.24, 0.42, 0.5),
        parent=turret, location=(0.0, 0.52, -0.02), material=mats["dark"],
    )
    studio.bevel(tail, width=0.02)

    # Heat fins, bigger than the base Lance's. An emitter driven harder has to
    # dump more, and the fins are where that reads.
    fin = studio.box(
        "AccentFin", size=(0.06, 0.5, 0.46),
        parent=turret, location=(0.26, 0.06, 0.26), material=mats["accent"],
    )
    fin.rotation_euler = (0.0, 0.34, 0.0)
    studio.mirror_x(fin, about=turret)
    studio.bevel(fin, width=0.012)

    barrel = studio.cylinder(
        "Barrel", radius_bottom=0.13, radius_top=0.1, height=BARREL_LENGTH,
        segments=8, parent=turret,
        location=(0.0, -(BARREL_LENGTH * 0.5 + 0.26), -0.02),
        material=mats["dark"], base_at_origin=False,
    )
    barrel.rotation_euler = (1.5708, 0.0, 0.0)
    studio.bevel(barrel, width=0.012)

    # Collimator rings down the emitter - "recollimated", made countable.
    for index, along in enumerate((-0.5, 0.0, 0.5)):
        _tier.ring("AccentCollimator%d" % (index + 1), barrel, radius=0.17,
                   z=along * BARREL_LENGTH * 0.5, material=mats["accent"],
                   thickness=0.08, segments=8)

    studio.cylinder(
        "Muzzle", radius_bottom=0.2, radius_top=0.16, height=0.16, segments=8,
        parent=barrel, location=(0.0, 0.0, BARREL_LENGTH * 0.5 - 0.02),
        material=mats["accent"], base_at_origin=False,
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
