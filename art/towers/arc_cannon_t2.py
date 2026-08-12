"""Overclock - Arc Cannon tier 2.

voice.md: "Twin feed lines double the cycle rate. Everything the cannon was,
twice as often." upgrades.md 4: 120 damage on a 16-tick interval, same range 8,
+90 credits. Its marginal efficiency deliberately equals the base cannon's - it
is the tutorial for the whole upgrade system and must never feel like a tax.

So the model is the base Arc Cannon with more of everything and no new ideas.
That restraint is the brief: upgrades.md 8 asks tier 2 for "the same silhouette,
visibly bulkier", and if Overclock invented a new shape there would be nothing
left for Hailstorm and Railshot to be different FROM.

The one literal reading of the flavour text: the base cannon carries a single
ammo drum on its left flank, and the asymmetry is its signature. Overclock has
TWO, mirrored. "Twin feed lines" is a thing the player can count.

Everything else is scale: wider pad, taller plinth, thicker barrels, a heavier
counterweight to balance them, and one rank band.

Node contract with game/views/tower_view.gd:
    Base    - static, on the ground, origin at y=0
    Turret  - pivot only (an empty), rotated on Y to face the target
    Barrel  - child of Turret, slid along +Z for recoil

Output: data/models/towers/arc_cannon_t2.glb
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, os.pardir, "lib"))
sys.path.insert(0, _HERE)

import studio  # noqa: E402
import _tier  # noqa: E402

OUTPUT_PATH = "data/models/towers/arc_cannon_t2.glb"

BARREL_LENGTH = 1.32          # base cannon is 1.20
PLINTH_HEIGHT = 0.95
COLLAR_HEIGHT = 0.32
TURRET_Z = 1.40


def build():
    studio.reset_scene()
    mats = _tier.materials()

    root = studio.empty("ArcCannonT2")

    pad = studio.cylinder(
        "Base", radius_bottom=0.82, radius_top=0.76, height=0.17, segments=8,
        parent=root, material=mats["dark"],
    )
    studio.bevel(pad, width=0.02)

    plinth = studio.cylinder(
        "Plinth", radius_bottom=0.64, radius_top=0.48,
        height=PLINTH_HEIGHT, segments=8,
        parent=pad, location=(0.0, 0.0, 0.15), material=mats["hull"],
    )
    studio.bevel(plinth, width=0.03)

    # One band. Sits high on the plinth where nothing overlaps it from above -
    # the RTS camera looks down, so a band near the base would be hidden by the
    # pad's own rim at exactly the distance it needs to be readable.
    # Low on the plinth, not high. The first pass put these near the collar and
    # the turret - a full 1.0 wide over a 0.64 plinth - occluded them from above,
    # which is the only angle the game is ever played from. The Lance and Mortar
    # families do not have this problem: their turrets are narrower than their
    # shafts. Checked in art/preview_towers.py, not by reasoning about it.
    _tier.rank_bands(plinth, 1, radius=0.53, base_z=PLINTH_HEIGHT * 0.30,
                     material=mats["accent"])

    collar = studio.cylinder(
        "Collar", radius_bottom=0.37, radius_top=0.41,
        height=COLLAR_HEIGHT, segments=12,
        parent=plinth, location=(0.0, 0.0, PLINTH_HEIGHT), material=mats["dark"],
    )
    studio.bevel(collar, width=0.02)

    strut = studio.box(
        "Strut", size=(0.18, 0.54, 0.5),
        parent=plinth, location=(0.55, 0.0, 0.22), material=mats["dark"],
    )
    studio.mirror_x(strut, about=plinth)
    studio.bevel(strut, width=0.02)

    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_Z))

    head = studio.wedge(
        "TurretHead", size=(1.0, 1.04, 0.56),
        parent=turret, material=mats["hull"], taper=0.58,
    )
    studio.bevel(head, width=0.03)

    tail = studio.box(
        "Counterweight", size=(0.62, 0.34, 0.44),
        parent=turret, location=(0.0, 0.6, -0.02), material=mats["dark"],
    )
    studio.bevel(tail, width=0.02)

    # The twin feed. Mirrored about the TURRET, not about the drum - the drum is
    # off-centre, and mirroring an off-centre part about itself folds it onto
    # itself. That bug shipped a single-barrelled Arc Cannon once already.
    drum = studio.cylinder(
        "AmmoDrum", radius_bottom=0.25, radius_top=0.25, height=0.36, segments=10,
        parent=turret, location=(-0.66, 0.14, 0.04), material=mats["accent"],
        base_at_origin=False,
    )
    drum.rotation_euler = (0.0, 1.5708, 0.0)
    studio.mirror_x(drum, about=turret)
    studio.bevel(drum, width=0.02)

    studio.box(
        "Sight", size=(0.2, 0.22, 0.12),
        parent=turret, location=(0.0, 0.1, 0.3), material=mats["accent"],
    )

    # Heat vents between the feeds - the visible cost of firing twice as often.
    vent = studio.box(
        "AccentVent", size=(0.1, 0.42, 0.08),
        parent=turret, location=(0.3, 0.3, 0.26), material=mats["glow"],
    )
    studio.mirror_x(vent, about=turret)

    barrel = studio.box(
        "Barrel", size=(0.18, BARREL_LENGTH, 0.18),
        parent=turret,
        location=(0.23, -(BARREL_LENGTH * 0.5 + 0.34), -0.04),
        material=mats["dark"],
    )
    studio.mirror_x(barrel, about=turret)
    studio.bevel(barrel, width=0.015)

    muzzle = studio.box(
        "Muzzle", size=(0.26, 0.22, 0.26),
        parent=barrel, location=(0.0, -(BARREL_LENGTH * 0.5 - 0.05), 0.0),
        material=mats["accent"],
    )
    studio.mirror_x(muzzle, about=turret)
    studio.bevel(muzzle, width=0.015)

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
