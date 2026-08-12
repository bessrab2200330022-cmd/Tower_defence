"""Deep Barrel - Frost Mortar tier 2.

voice.md: "A longer barrel, a heavier shell. Wider frost, longer chill."
upgrades.md 6: 220 damage, 80 ticks, splash 3.0 -> 3.6, slow 40% for 150 ticks.

The mortar family is the answer to TIME - it does not kill the wave, it sells
the wave to your other towers at a discount. Tier 2 buys more of every axis at
once and invents nothing, which is what upgrades.md 8 asks tier 2 to be.

Two countable changes, in the family's own vocabulary: the base mortar carries
two coolant tanks around its drum, so this carries FOUR; and the barrel grows
from 1.0 to 1.35, which is the name of the tier.

The base pad is the tightest footprint constraint in the project. The shipped
Frost Mortar is already 1.700 across against art/README.md's "keep towers' bases
under about 1.8", so this family has roughly 0.05 of headroom in total and the
tier ladder has to be spent on HEIGHT rather than width. Every radius here is
measured against that ceiling, not chosen for looks.

Output: data/models/towers/frost_mortar_t2.glb
"""

import math
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, os.pardir, "lib"))
sys.path.insert(0, _HERE)

import studio  # noqa: E402
import _tier  # noqa: E402

OUTPUT_PATH = "data/models/towers/frost_mortar_t2.glb"

DRUM_HEIGHT = 0.68
COLLAR_HEIGHT = 0.26
BARREL_LENGTH = 1.35
TURRET_Z = 1.16
ELEVATION_DEG = 40.0


def build():
    studio.reset_scene()
    mats = _tier.materials()

    root = studio.empty("FrostMortarT2")

    # 0.87, against the shipped mortar's 0.86 and the 0.90 that art/README.md's
    # 1.8-across rule allows. Almost all the headroom this family has.
    pad = studio.prism("Base", radius=0.87, height=0.17, segments=8,
                       parent=root, material=mats["dark"])
    studio.bevel(pad, width=0.025)

    drum = studio.cylinder(
        "Plinth", radius_bottom=0.75, radius_top=0.68,
        height=DRUM_HEIGHT, segments=10,
        parent=pad, location=(0.0, 0.0, 0.15), material=mats["hull"],
    )
    studio.bevel(drum, width=0.03)

    _tier.rank_bands(drum, 1, radius=0.72, base_z=DRUM_HEIGHT * 0.5,
                     material=mats["accent"])

    # Four tanks where the base mortar has two. radial() puts them on the
    # diagonals so none sits directly in front of the barrel.
    for index, x, y, _angle in _tier.radial(4, 0.63, start_deg=45.0):
        tank = studio.cylinder(
            "AccentTank%d" % (index + 1),
            radius_bottom=0.16, radius_top=0.16, height=0.52, segments=8,
            parent=drum, location=(x, y, 0.09), material=mats["accent"],
        )
        studio.bevel(tank, width=0.02)

    collar = studio.cylinder(
        "Collar", radius_bottom=0.46, radius_top=0.5,
        height=COLLAR_HEIGHT, segments=12,
        parent=drum, location=(0.0, 0.0, DRUM_HEIGHT), material=mats["dark"],
    )
    studio.bevel(collar, width=0.02)

    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_Z))

    head = studio.wedge(
        "TurretHead", size=(0.98, 0.8, 0.42),
        parent=turret, material=mats["hull"], taper=0.7,
    )
    studio.bevel(head, width=0.025)

    # Trunnion the barrel pivots in. A mortar without one looks like a pipe
    # glued to a box.
    # x MUST be 0. studio.cylinder(base_at_origin=False) centres the tube on
    # its own origin, so after the Y rotation it spans +/- height/2 about
    # `location`. Offsetting x by half the length - which is what this first
    # had - pushes the whole axle out one flank: frost_mortar_t3a measured
    # 1.950 across with the trunnion reaching x = -1.08 and nothing on the
    # right. A trunnion is the axle the barrel pivots in and pokes out BOTH
    # sides. The shipped frost_mortar.glb has it at X[-0.480, 0.480]; match it.
    trunnion = studio.cylinder(
        "AccentTrunnion", radius_bottom=0.15, radius_top=0.15, height=1.0,
        segments=8, parent=turret, location=(0.0, 0.06, 0.1),
        material=mats["accent"], base_at_origin=False,
    )
    trunnion.rotation_euler = (0.0, 1.5708, 0.0)
    studio.bevel(trunnion, width=0.015)

    tail = studio.box(
        "Counterweight", size=(0.36, 0.34, 0.38),
        parent=turret, location=(0.0, 0.5, -0.04), material=mats["dark"],
    )
    studio.bevel(tail, width=0.02)

    # Negative X rotation lifts the -Y (forward) end: a mortar lobs.
    barrel = studio.cylinder(
        "Barrel", radius_bottom=0.24, radius_top=0.22, height=BARREL_LENGTH,
        segments=10, parent=turret, location=(0.0, -0.18, 0.06),
        material=mats["dark"], base_at_origin=False,
    )
    barrel.rotation_euler = (math.radians(90.0 - ELEVATION_DEG), 0.0, 0.0)
    studio.bevel(barrel, width=0.02)

    for index, along in enumerate((-0.4, 0.1)):
        _tier.ring("AccentBand%d" % (index + 1), barrel, radius=0.27,
                   z=along * BARREL_LENGTH, material=mats["accent"],
                   thickness=0.09, segments=10)

    studio.cylinder(
        "Muzzle", radius_bottom=0.29, radius_top=0.26, height=0.16, segments=10,
        parent=barrel, location=(0.0, 0.0, BARREL_LENGTH * 0.5 - 0.02),
        material=mats["accent"], base_at_origin=False,
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
