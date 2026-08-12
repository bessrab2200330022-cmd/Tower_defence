"""Hailstorm - Arc Cannon tier 3A, the swarm terminal.

voice.md: "Rotary flak that bursts on impact. Packs get shredded; a lone target
barely notices the upgrade." upgrades.md 4: 70 damage every 10 ticks with a 2.0
splash - deliberately a single-target DOWNGRADE from Overclock, with all the
gain living in the splash.

upgrades.md 8 asks for "multi-barrel rotary", and that is the right shape for a
reason beyond looking like a Gatling: the fork's other branch, Railshot, is one
enormous barrel. Six small versus one huge is the most legible pair of
silhouettes available from the same turret, and it survives being 40 units away
and half-occluded by a Brute.

The rotary is built as a hub named Barrel with six sub-barrels parented to it,
NOT as six siblings. tower_view.gd slides the node called Barrel along +Z for
recoil; six siblings would need six recoil targets and would get one, so five
barrels would sit still while one kicked.

Output: data/models/towers/arc_cannon_t3a.glb
"""

import math
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, os.pardir, "lib"))
sys.path.insert(0, _HERE)

import studio  # noqa: E402
import _tier  # noqa: E402

OUTPUT_PATH = "data/models/towers/arc_cannon_t3a.glb"

# First build put the rotary at 1.780 against Overclock's 1.760 - a 0.02 gap,
# which is no gap at all once the camera is 40 units back. Raised so the
# ladder is carried by height as well as by the barrel count.
PLINTH_HEIGHT = 1.10
COLLAR_HEIGHT = 0.32
TURRET_Z = 1.56

BARREL_COUNT = 6
BARREL_RING = 0.24            # how far each barrel sits off the spin axis
BARREL_LENGTH = 1.12          # short: flak, not reach


def build():
    studio.reset_scene()
    mats = _tier.materials()

    root = studio.empty("ArcCannonT3a")

    pad = studio.cylinder(
        "Base", radius_bottom=0.84, radius_top=0.78, height=0.17, segments=8,
        parent=root, material=mats["dark"],
    )
    studio.bevel(pad, width=0.02)

    plinth = studio.cylinder(
        "Plinth", radius_bottom=0.66, radius_top=0.5,
        height=PLINTH_HEIGHT, segments=8,
        parent=pad, location=(0.0, 0.0, 0.15), material=mats["hull"],
    )
    studio.bevel(plinth, width=0.03)

    # Low on the plinth, not high. The first pass put these near the collar and
    # the turret - a full 1.0 wide over a 0.64 plinth - occluded them from above,
    # which is the only angle the game is ever played from. The Lance and Mortar
    # families do not have this problem: their turrets are narrower than their
    # shafts. Checked in art/preview_towers.py, not by reasoning about it.
    _tier.rank_bands(plinth, 2, radius=0.55, base_z=PLINTH_HEIGHT * 0.28,
                     material=mats["accent"])

    collar = studio.cylinder(
        "Collar", radius_bottom=0.38, radius_top=0.42,
        height=COLLAR_HEIGHT, segments=12,
        parent=plinth, location=(0.0, 0.0, PLINTH_HEIGHT), material=mats["dark"],
    )
    studio.bevel(collar, width=0.02)

    strut = studio.box(
        "Strut", size=(0.18, 0.56, 0.52),
        parent=plinth, location=(0.56, 0.0, 0.22), material=mats["dark"],
    )
    studio.mirror_x(strut, about=plinth)
    studio.bevel(strut, width=0.02)

    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_Z))

    head = studio.wedge(
        "TurretHead", size=(0.98, 0.9, 0.6),
        parent=turret, material=mats["hull"], taper=0.66,
    )
    studio.bevel(head, width=0.03)

    tail = studio.box(
        "Counterweight", size=(0.66, 0.36, 0.46),
        parent=turret, location=(0.0, 0.56, -0.02), material=mats["dark"],
    )
    studio.bevel(tail, width=0.02)

    # Ammunition hoppers, one per flank. A gun firing every 10 ticks needs to
    # look like it is being fed, and this is the family's inherited motif.
    drum = studio.cylinder(
        "AmmoDrum", radius_bottom=0.27, radius_top=0.27, height=0.34, segments=10,
        parent=turret, location=(-0.66, 0.2, 0.06), material=mats["accent"],
        base_at_origin=False,
    )
    drum.rotation_euler = (0.0, 1.5708, 0.0)
    studio.mirror_x(drum, about=turret)
    studio.bevel(drum, width=0.02)

    # --- the rotary ------------------------------------------------------
    # studio.cylinder builds along +Z. Rotating +90 degrees about X maps local
    # +Z onto world -Y, which the exporter turns into Godot +Z - the direction a
    # turret faces at rotation 0. Everything parented to the hub inherits that,
    # so the sub-barrels are placed in the hub's LOCAL xy and run along local +Z.
    hub = studio.cylinder(
        "Barrel", radius_bottom=0.34, radius_top=0.3, height=0.34, segments=10,
        parent=turret, location=(0.0, -0.5, -0.02), material=mats["dark"],
        base_at_origin=False,
    )
    hub.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
    studio.bevel(hub, width=0.02)

    for index, x, y, _angle in _tier.radial(BARREL_COUNT, BARREL_RING, start_deg=30.0):
        tube = studio.cylinder(
            "AccentTube%d" % (index + 1),
            radius_bottom=0.062, radius_top=0.058, height=BARREL_LENGTH, segments=6,
            parent=hub, location=(x, y, 0.0), material=mats["dark"],
            base_at_origin=False,
        )
        studio.bevel(tube, width=0.008)

    # Muzzle plate across the front of the cluster. Also the one node named
    # exactly "Muzzle", so this tier still has an accent-tinted part under
    # tower_view.gd's current exact-match list. See _tier.py.
    studio.cylinder(
        "Muzzle", radius_bottom=0.36, radius_top=0.32, height=0.12, segments=10,
        parent=hub, location=(0.0, 0.0, BARREL_LENGTH * 0.5 + 0.02),
        material=mats["accent"], base_at_origin=False,
    )

    # Spin housing behind the cluster, so the barrels look driven rather than
    # bundled.
    studio.cylinder(
        "AccentDrive", radius_bottom=0.2, radius_top=0.26, height=0.2, segments=8,
        parent=hub, location=(0.0, 0.0, -BARREL_LENGTH * 0.5 - 0.06),
        material=mats["accent"], base_at_origin=False,
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
