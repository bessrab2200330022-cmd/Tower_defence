"""Fork Array - Plasma Lance tier 3B, the sustained-pressure pick.

voice.md: "The beam splits on contact, arcing to two nearby machines at half
charge. Built for shielded columns." upgrades.md 5: 480 to the primary, 240 to
up to two more within 4.0.

BUILT AHEAD OF ITS MECHANIC, ON PURPOSE. docs/ROUND-2.md defers the fork
targeting to a later round and ships the Lance with Prime Focus as a lone
tier-3. The model is built anyway because the cost is one script now against
re-deriving a whole family's visual language later - and because Prime Focus was
DESIGNED against this sibling. Its "gather the array into one lens" only reads as
a choice if the thing it is not is also on the board.

    Prime Focus   three trunks -> one lens.   Convergence.
    Fork Array    one feed     -> three prongs. Divergence.

Same pylon, same mount, opposite geometry. That opposition is the fork.

The two outer prongs are parented to Barrel and splay from it, so the whole
trident recoils as one piece - and so the "split" is structural rather than
decorative: the beam path physically divides at the emitter.

Output: data/models/towers/plasma_lance_t3b.glb
"""

import math
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, os.pardir, "lib"))
sys.path.insert(0, _HERE)

import studio  # noqa: E402
import _tier  # noqa: E402

OUTPUT_PATH = "data/models/towers/plasma_lance_t3b.glb"

# Fork Array first measured 2.239 against Focused Array's 2.413 - a tier-3
# standing SHORTER than the tier-2 it is bought from. Nothing else in the
# ladder may do that: an upgrade that looks smaller reads as a downgrade, and
# the player has no UI to correct the impression. Now sits above its parent
# and just under Prime Focus, which stays the tallest tower in the game.
PYLON_HEIGHT = 1.82
PRONG_LENGTH = 1.35
TURRET_Z = 2.27


def build():
    studio.reset_scene()
    mats = _tier.materials()

    root = studio.empty("PlasmaLanceT3b")

    pad = studio.cylinder(
        "Base", radius_bottom=0.76, radius_top=0.72, height=0.19, segments=6,
        parent=root, material=mats["dark"],
    )
    studio.bevel(pad, width=0.02)

    plinth = studio.cylinder(
        "Plinth", radius_bottom=0.52, radius_top=0.31,
        height=PYLON_HEIGHT, segments=6,
        parent=pad, location=(0.0, 0.0, 0.17), material=mats["hull"],
    )
    studio.bevel(plinth, width=0.025)

    _tier.rank_bands(plinth, 2, radius=0.44, base_z=PYLON_HEIGHT * 0.32,
                     material=mats["accent"])

    # A single heavy trunk up the front face. One feed in, three out - the
    # divergence starts at the shaft, not at the muzzle.
    trunk = studio.box(
        "AccentTrunk", size=(0.2, 0.14, PYLON_HEIGHT * 0.7),
        parent=plinth, location=(0.0, -0.34, PYLON_HEIGHT * 0.42),
        material=mats["glow"],
    )
    studio.bevel(trunk, width=0.012)

    collar = studio.cylinder(
        "Collar", radius_bottom=0.29, radius_top=0.36, height=0.3, segments=12,
        parent=plinth, location=(0.0, 0.0, PYLON_HEIGHT), material=mats["dark"],
    )
    studio.bevel(collar, width=0.02)

    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_Z))

    # Wide head: it has to physically carry three emitters side by side, and the
    # width is half of why this reads differently from Prime Focus's narrow one.
    head = studio.wedge(
        "TurretHead", size=(0.94, 0.84, 0.5),
        parent=turret, material=mats["hull"], taper=0.85,
    )
    studio.bevel(head, width=0.025)

    tail = studio.box(
        "Counterweight", size=(0.3, 0.46, 0.5),
        parent=turret, location=(0.0, 0.5, -0.02), material=mats["dark"],
    )
    studio.bevel(tail, width=0.02)

    # --- the trident -----------------------------------------------------
    # Centre prong is Barrel; the pair splay off it and recoil with it.
    barrel = studio.cylinder(
        "Barrel", radius_bottom=0.12, radius_top=0.08, height=PRONG_LENGTH,
        segments=8, parent=turret,
        location=(0.0, -(PRONG_LENGTH * 0.5 + 0.24), 0.0),
        material=mats["dark"], base_at_origin=False,
    )
    barrel.rotation_euler = (1.5708, 0.0, 0.0)
    studio.bevel(barrel, width=0.012)

    # In Barrel's local frame the emitter axis is +Z, so a prong splays by
    # rotating about local Y and offsetting along local X.
    prong = studio.cylinder(
        "AccentProng", radius_bottom=0.1, radius_top=0.065,
        height=PRONG_LENGTH * 0.82, segments=8,
        parent=barrel, location=(0.2, 0.0, -0.06),
        material=mats["dark"], base_at_origin=False,
    )
    prong.rotation_euler = (0.0, math.radians(16.0), 0.0)
    studio.mirror_x(prong, about=barrel)
    studio.bevel(prong, width=0.01)

    tip = studio.cylinder(
        "AccentProngTip", radius_bottom=0.13, radius_top=0.1, height=0.12,
        segments=8, parent=barrel,
        location=(0.31, 0.0, PRONG_LENGTH * 0.36),
        material=mats["glow"], base_at_origin=False,
    )
    tip.rotation_euler = (0.0, math.radians(16.0), 0.0)
    studio.mirror_x(tip, about=barrel)

    # The splitter block where one feed becomes three.
    studio.box(
        "AccentSplitter", size=(0.5, 0.22, 0.22),
        parent=barrel, location=(0.0, 0.0, -PRONG_LENGTH * 0.34),
        material=mats["accent"],
    )

    studio.cylinder(
        "Muzzle", radius_bottom=0.16, radius_top=0.12, height=0.14, segments=8,
        parent=barrel, location=(0.0, 0.0, PRONG_LENGTH * 0.5 - 0.02),
        material=mats["accent"], base_at_origin=False,
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
