"""Glacier - Frost Mortar tier 3A, the control terminal.

voice.md: "Saturation frost. Inside the blast the tide moves at a crawl - your
lances do the rest." upgrades.md 6: damage UNCHANGED from Deep Barrel, splash
4.5, slow 60% for 180 ticks. You are buying seconds, not hit points, and the
family invariant is that no other source of slow may ever exceed this one.

upgrades.md 8 asks for "a broad squat mortar with vanes", and squat is doing the
real work. Glacier is the only tier in the project that is SHORTER than the tier
below it - about 1.55 against Deep Barrel's 1.9 - and that inversion is
deliberate on two counts:

  * It is the clearest possible statement that this branch did not buy damage.
    Every other upgrade in the game grows upward; the one that converts its
    purchase into area and duration instead spreads outward.
  * It makes the fork unmistakable. Shatterhead is the tallest thing in the
    family and Glacier the shortest, from the same tier-2 parent. You can tell
    which branch a player took from across the board, with no UI, which is
    exactly what upgrades.md 8 asks for.

Eight radiator vanes fan off the drum. They are the "vanes" of the brief and
also the widest geometry here, so their reach is set against art/README.md's
1.8-across ceiling and not by eye - this family has almost no width headroom
left.

Output: data/models/towers/frost_mortar_t3a.glb
"""

import math
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, os.pardir, "lib"))
sys.path.insert(0, _HERE)

import studio  # noqa: E402
import _tier  # noqa: E402

OUTPUT_PATH = "data/models/towers/frost_mortar_t3a.glb"

# Glacier is meant to be the short one, and first built at 1.671 - which is
# below the BASE mortar's 1.709. Squatter than its tier-2 sibling is the
# design; squatter than the un-upgraded tower is a bug, because the one thing
# a tier must never look like is tier 1.
DRUM_HEIGHT = 0.58
COLLAR_HEIGHT = 0.2
BARREL_LENGTH = 1.0
TURRET_Z = 1.03
ELEVATION_DEG = 54.0          # steeper than Deep Barrel: saturation, not reach
VANE_COUNT = 8


def build():
    studio.reset_scene()
    mats = _tier.materials()

    root = studio.empty("FrostMortarT3a")

    pad = studio.prism("Base", radius=0.88, height=0.15, segments=8,
                       parent=root, material=mats["dark"])
    studio.bevel(pad, width=0.025)

    # Wide and low. The drum is nearly as broad as the pad it stands on, which
    # is what "squat" means here - no visible waist.
    drum = studio.cylinder(
        "Plinth", radius_bottom=0.82, radius_top=0.76,
        height=DRUM_HEIGHT, segments=10,
        parent=pad, location=(0.0, 0.0, 0.13), material=mats["hull"],
    )
    studio.bevel(drum, width=0.03)

    _tier.rank_bands(drum, 2, radius=0.79, base_z=DRUM_HEIGHT * 0.24,
                     spacing=0.14, material=mats["accent"])

    # Radiator vanes. Thin plates standing off the drum, angled so they catch
    # light differently from the flat drum wall behind them. Max reach is
    # 0.855 from centre = 1.71 across, inside the 1.8 ceiling.
    for index, x, y, angle in _tier.radial(VANE_COUNT, 0.79, start_deg=22.5):
        vane = studio.box(
            "AccentVane%d" % (index + 1), size=(0.13, 0.05, 0.42),
            parent=drum, location=(x, y, 0.2), material=mats["accent"],
        )
        vane.rotation_euler = (0.0, 0.0, angle)
        studio.bevel(vane, width=0.008)

    collar = studio.cylinder(
        "Collar", radius_bottom=0.5, radius_top=0.54,
        height=COLLAR_HEIGHT, segments=12,
        parent=drum, location=(0.0, 0.0, DRUM_HEIGHT), material=mats["dark"],
    )
    studio.bevel(collar, width=0.02)

    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_Z))

    # Broad, flat head to match the chassis under it.
    head = studio.wedge(
        "TurretHead", size=(1.06, 0.74, 0.34),
        parent=turret, material=mats["hull"], taper=0.82,
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
        "AccentTrunnion", radius_bottom=0.16, radius_top=0.16, height=1.08,
        segments=8, parent=turret, location=(0.0, 0.04, 0.06),
        material=mats["accent"], base_at_origin=False,
    )
    trunnion.rotation_euler = (0.0, 1.5708, 0.0)
    studio.bevel(trunnion, width=0.015)

    tail = studio.box(
        "Counterweight", size=(0.42, 0.3, 0.3),
        parent=turret, location=(0.0, 0.44, -0.04), material=mats["dark"],
    )
    studio.bevel(tail, width=0.02)

    # Wide-bore, short. A saturation weapon: it has to look like it throws a
    # volume rather than a projectile.
    barrel = studio.cylinder(
        "Barrel", radius_bottom=0.31, radius_top=0.34, height=BARREL_LENGTH,
        segments=10, parent=turret, location=(0.0, -0.12, 0.05),
        material=mats["dark"], base_at_origin=False,
    )
    barrel.rotation_euler = (math.radians(90.0 - ELEVATION_DEG), 0.0, 0.0)
    studio.bevel(barrel, width=0.02)

    studio.cylinder(
        "Muzzle", radius_bottom=0.4, radius_top=0.36, height=0.18, segments=10,
        parent=barrel, location=(0.0, 0.0, BARREL_LENGTH * 0.5 - 0.01),
        material=mats["accent"], base_at_origin=False,
    )

    # Chill core in the throat, so the widest bore in the game reads as loaded.
    studio.cylinder(
        "AccentCore", radius_bottom=0.26, radius_top=0.24, height=0.1, segments=10,
        parent=barrel, location=(0.0, 0.0, BARREL_LENGTH * 0.5 - 0.07),
        material=mats["glow"], base_at_origin=False,
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
