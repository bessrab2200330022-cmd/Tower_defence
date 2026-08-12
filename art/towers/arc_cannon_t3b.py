"""Railshot - Arc Cannon tier 3B, the elite-hunter pivot.

voice.md: "One long rail, one heavy slug, a longer reach. Still kinetic - shields
still don't care." upgrades.md 4: 480 damage on a 60-tick interval at range 12,
default target mode Strongest.

Range is the stat that has no silhouette. Damage shows as a big muzzle, rate of
fire shows as feed hardware - but "reaches four units further than anything else
in the family" can only be read as LENGTH. So the rail is 2.30 units, nearly
twice the base cannon's 1.20 and by a distance the longest barrel in the game.
A player who has seen one Railshot should recognise the next one from its
shadow.

It is also the deliberate opposite of its sibling: Hailstorm is six short tubes
on a fat rotary hub, Railshot is one long spar on a narrow turret. Same pad,
same family, no chance of confusing them at range.

The rail spars are parented to Barrel, not to Turret, so the whole assembly
recoils as one piece. A rail that kicks while its own rails stand still would
read as a rigging error.

Output: data/models/towers/arc_cannon_t3b.glb
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, os.pardir, "lib"))
sys.path.insert(0, _HERE)

import studio  # noqa: E402
import _tier  # noqa: E402

OUTPUT_PATH = "data/models/towers/arc_cannon_t3b.glb"

# 2.05, down from the 2.30 first built: at 2.30 the model measured 3.64 deep,
# so the muzzle swept 1.3 tiles either side of its own pad and would clip a
# neighbouring tower. art/README.md permits barrel overhang - turrets rotate -
# but 1.3 tiles is past what 'expected' covers. Still the longest gun in the
# game by a wide margin, which is the only way range 12 has a silhouette.
BARREL_LENGTH = 2.05
PLINTH_HEIGHT = 1.18
COLLAR_HEIGHT = 0.3
TURRET_Z = 1.62


def build():
    studio.reset_scene()
    mats = _tier.materials()

    root = studio.empty("ArcCannonT3b")

    # Narrower pad than Hailstorm's. This is a precision weapon and should not
    # look like it needs the same ground as a flak battery.
    pad = studio.cylinder(
        "Base", radius_bottom=0.78, radius_top=0.72, height=0.18, segments=8,
        parent=root, material=mats["dark"],
    )
    studio.bevel(pad, width=0.02)

    plinth = studio.cylinder(
        "Plinth", radius_bottom=0.6, radius_top=0.42,
        height=PLINTH_HEIGHT, segments=8,
        parent=pad, location=(0.0, 0.0, 0.16), material=mats["hull"],
    )
    studio.bevel(plinth, width=0.03)

    # Low on the plinth, not high. The first pass put these near the collar and
    # the turret - a full 1.0 wide over a 0.64 plinth - occluded them from above,
    # which is the only angle the game is ever played from. The Lance and Mortar
    # families do not have this problem: their turrets are narrower than their
    # shafts. Checked in art/preview_towers.py, not by reasoning about it.
    _tier.rank_bands(plinth, 2, radius=0.5, base_z=PLINTH_HEIGHT * 0.30,
                     material=mats["accent"])

    collar = studio.cylinder(
        "Collar", radius_bottom=0.32, radius_top=0.36,
        height=COLLAR_HEIGHT, segments=12,
        parent=plinth, location=(0.0, 0.0, PLINTH_HEIGHT), material=mats["dark"],
    )
    studio.bevel(collar, width=0.02)

    strut = studio.box(
        "Strut", size=(0.16, 0.52, 0.56),
        parent=plinth, location=(0.5, 0.0, 0.24), material=mats["dark"],
    )
    studio.mirror_x(strut, about=plinth)
    studio.bevel(strut, width=0.02)

    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_Z))

    # Narrow head. The rail is the read; the turret should get out of its way.
    head = studio.wedge(
        "TurretHead", size=(0.64, 1.0, 0.5),
        parent=turret, material=mats["hull"], taper=0.5,
    )
    studio.bevel(head, width=0.03)

    # Heavy counterweight. A 2.3-unit barrel on a 0.64-wide turret looks like it
    # should topple; the block behind it is what makes the balance believable.
    tail = studio.box(
        "Counterweight", size=(0.56, 0.6, 0.5),
        parent=turret, location=(0.0, 0.68, -0.04), material=mats["dark"],
    )
    studio.bevel(tail, width=0.025)

    # Capacitor bank feeding the rail - the family's ammo motif, restated as
    # stored charge rather than as loose rounds.
    bank = studio.box(
        "AmmoDrum", size=(0.16, 0.5, 0.3),
        parent=turret, location=(0.4, 0.34, 0.16), material=mats["accent"],
    )
    studio.mirror_x(bank, about=turret)
    studio.bevel(bank, width=0.015)

    studio.box(
        "Sight", size=(0.16, 0.3, 0.11),
        parent=turret, location=(0.0, 0.16, 0.29), material=mats["accent"],
    )

    # --- the rail --------------------------------------------------------
    barrel = studio.box(
        "Barrel", size=(0.16, BARREL_LENGTH, 0.17),
        parent=turret,
        location=(0.0, -(BARREL_LENGTH * 0.5 + 0.3), -0.02),
        material=mats["dark"],
    )
    studio.bevel(barrel, width=0.015)

    # The two rails proper, flanking the slug channel. Parented to Barrel so
    # they recoil with it. Barrel sits on x = 0, so mirroring about it is safe.
    spar = studio.box(
        "AccentRail", size=(0.075, BARREL_LENGTH * 0.88, 0.3),
        parent=barrel, location=(0.17, 0.06, 0.0), material=mats["accent"],
    )
    studio.mirror_x(spar, about=barrel)
    studio.bevel(spar, width=0.01)

    # Three bracing collars down the length, so a 2.3-unit spar reads as
    # engineered rather than as a stretched box.
    for index, along in enumerate((-0.62, 0.0, 0.62)):
        brace = studio.box(
            "AccentBrace%d" % (index + 1), size=(0.42, 0.09, 0.4),
            parent=barrel, location=(0.0, along * BARREL_LENGTH * 0.5, 0.0),
            material=mats["dark"],
        )
        studio.bevel(brace, width=0.01)

    studio.box(
        "Muzzle", size=(0.3, 0.24, 0.32),
        parent=barrel, location=(0.0, -(BARREL_LENGTH * 0.5 - 0.06), 0.0),
        material=mats["accent"],
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
