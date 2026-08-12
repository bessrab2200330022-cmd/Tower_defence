"""Shatterhead - Frost Mortar tier 3B, the damage pivot.

voice.md: "Fragmenting shells trade most of the chill for raw blast. Drone packs
simply end." upgrades.md 6: 420 damage, 70 ticks, splash 3.4, slow cut to 20%
for 60 ticks. Its single-target DPS stays below every Lance tier - the mortar
never becomes a sniper - but into Light armour a centre hit is 546 and a drone
pack is over.

upgrades.md 8 asks for "a reinforced heavy barrel", and reinforcement is the
whole read: four banding rings up a thick tube, a breech block behind it, and a
brace under the muzzle. The base mortar's barrel is a smooth pipe; this one
looks like it is being held together against what it fires.

It is also the tallest mortar in the family at roughly 2.0 units against
Glacier's 1.55. That gap is the fork, and it is the only signal that survives
being read at RTS distance through a crowded lane - see the note in
frost_mortar_t3a.py, which was designed against this one.

Flatter elevation than Glacier, too: 30 degrees against 54. A fragmentation
shell is thrown at the wave, not over it.

Output: data/models/towers/frost_mortar_t3b.glb
"""

import math
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, os.pardir, "lib"))
sys.path.insert(0, _HERE)

import studio  # noqa: E402
import _tier  # noqa: E402

OUTPUT_PATH = "data/models/towers/frost_mortar_t3b.glb"

DRUM_HEIGHT = 0.8
COLLAR_HEIGHT = 0.3
BARREL_LENGTH = 1.5
TURRET_Z = 1.34
ELEVATION_DEG = 30.0


def build():
    studio.reset_scene()
    mats = _tier.materials()

    root = studio.empty("FrostMortarT3b")

    # Narrower than Glacier's 0.88. The mass here is vertical, not spread.
    pad = studio.prism("Base", radius=0.8, height=0.18, segments=8,
                       parent=root, material=mats["dark"])
    studio.bevel(pad, width=0.025)

    drum = studio.cylinder(
        "Plinth", radius_bottom=0.68, radius_top=0.6,
        height=DRUM_HEIGHT, segments=10,
        parent=pad, location=(0.0, 0.0, 0.16), material=mats["hull"],
    )
    studio.bevel(drum, width=0.03)

    _tier.rank_bands(drum, 2, radius=0.65, base_z=DRUM_HEIGHT * 0.42,
                     material=mats["accent"])

    # Two tanks only. Shatterhead traded most of its chill away, so it needs
    # less coolant than Deep Barrel's four - the count runs BACKWARDS here, and
    # that is the point: the player who counted four on tier 2 sees two and
    # reads "this one gave something up".
    for index, x, y, _angle in _tier.radial(2, 0.6, start_deg=90.0):
        tank = studio.cylinder(
            "AccentTank%d" % (index + 1),
            radius_bottom=0.15, radius_top=0.15, height=0.5, segments=8,
            parent=drum, location=(x, y, 0.14), material=mats["accent"],
        )
        studio.bevel(tank, width=0.02)

    collar = studio.cylinder(
        "Collar", radius_bottom=0.42, radius_top=0.46,
        height=COLLAR_HEIGHT, segments=12,
        parent=drum, location=(0.0, 0.0, DRUM_HEIGHT), material=mats["dark"],
    )
    studio.bevel(collar, width=0.02)

    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_Z))

    head = studio.wedge(
        "TurretHead", size=(0.86, 0.86, 0.5),
        parent=turret, material=mats["hull"], taper=0.62,
    )
    studio.bevel(head, width=0.025)

    # x MUST be 0. studio.cylinder(base_at_origin=False) centres the tube on
    # its own origin, so after the Y rotation it spans +/- height/2 about
    # `location`. Offsetting x by half the length - which is what this first
    # had - pushes the whole axle out one flank: frost_mortar_t3a measured
    # 1.950 across with the trunnion reaching x = -1.08 and nothing on the
    # right. A trunnion is the axle the barrel pivots in and pokes out BOTH
    # sides. The shipped frost_mortar.glb has it at X[-0.480, 0.480]; match it.
    trunnion = studio.cylinder(
        "AccentTrunnion", radius_bottom=0.14, radius_top=0.14, height=0.94,
        segments=8, parent=turret, location=(0.0, 0.02, 0.08),
        material=mats["accent"], base_at_origin=False,
    )
    trunnion.rotation_euler = (0.0, 1.5708, 0.0)
    studio.bevel(trunnion, width=0.015)

    # Breech block. The heaviest single piece behind the barrel, and the reason
    # the reinforcement reads as necessary rather than as decoration.
    breech = studio.box(
        "Counterweight", size=(0.44, 0.44, 0.46),
        parent=turret, location=(0.0, 0.46, -0.02), material=mats["dark"],
    )
    studio.bevel(breech, width=0.025)

    barrel = studio.cylinder(
        "Barrel", radius_bottom=0.25, radius_top=0.23, height=BARREL_LENGTH,
        segments=10, parent=turret, location=(0.0, -0.16, 0.04),
        material=mats["dark"], base_at_origin=False,
    )
    barrel.rotation_euler = (math.radians(90.0 - ELEVATION_DEG), 0.0, 0.0)
    studio.bevel(barrel, width=0.02)

    # Four bands. Deep Barrel has two; this is the same idea, reinforced, and
    # countable at the distance the player actually plays at.
    for index, along in enumerate((-0.42, -0.16, 0.1, 0.34)):
        _tier.ring("AccentBand%d" % (index + 1), barrel, radius=0.29,
                   z=along * BARREL_LENGTH, material=mats["accent"],
                   thickness=0.1, segments=10)

    studio.cylinder(
        "Muzzle", radius_bottom=0.33, radius_top=0.3, height=0.2, segments=10,
        parent=barrel, location=(0.0, 0.0, BARREL_LENGTH * 0.5 - 0.02),
        material=mats["accent"], base_at_origin=False,
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
