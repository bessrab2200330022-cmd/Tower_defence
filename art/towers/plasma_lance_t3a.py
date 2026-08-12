"""Prime Focus - Plasma Lance tier 3A, the executioner.

voice.md: "The whole array behind a single emitter. One target at a time stops
existing." upgrades.md 5: 1000 damage, 90 ticks, range 16 - the largest per-shot
alpha in the game by a factor of two, and the worst per-credit tower against a
swarm because 800 into a 600 HP drone wastes a quarter of every trigger pull.

"The whole array behind a single emitter" is a modelling instruction, so it is
taken literally: the five slim rods of Focused Array collapse into one enormous
lens, and the barrel is short and fat rather than long and thin. Where Fork
Array splays outward into three prongs, this converges inward to one. The pair
has to be readable as a genuine fork, not as two variants of the same gun, and
converge-versus-diverge is the clearest opposition available on a shared mount.

The tallest tower in the game at roughly 2.4 units, which is also the range read
- 16 is the longest reach on the board and it should look like it can see.

Output: data/models/towers/plasma_lance_t3a.glb
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, os.pardir, "lib"))
sys.path.insert(0, _HERE)

import studio  # noqa: E402
import _tier  # noqa: E402

OUTPUT_PATH = "data/models/towers/plasma_lance_t3a.glb"

PYLON_HEIGHT = 1.78
BARREL_LENGTH = 0.95
TURRET_Z = 2.22


def build():
    studio.reset_scene()
    mats = _tier.materials()

    root = studio.empty("PlasmaLanceT3a")

    pad = studio.cylinder(
        "Base", radius_bottom=0.78, radius_top=0.74, height=0.2, segments=6,
        parent=root, material=mats["dark"],
    )
    studio.bevel(pad, width=0.02)

    plinth = studio.cylinder(
        "Plinth", radius_bottom=0.54, radius_top=0.32,
        height=PYLON_HEIGHT, segments=6,
        parent=pad, location=(0.0, 0.0, 0.18), material=mats["hull"],
    )
    studio.bevel(plinth, width=0.025)

    _tier.rank_bands(plinth, 2, radius=0.46, base_z=PYLON_HEIGHT * 0.3,
                     material=mats["accent"])

    # The array, gathered. Three heavy trunks rather than five slim rods: the
    # charge is being concentrated, and the shaft should look like it is
    # carrying more current through fewer paths.
    for index, x, y, _angle in _tier.radial(3, 0.4, start_deg=90.0):
        trunk = studio.box(
            "AccentTrunk%d" % (index + 1),
            size=(0.15, 0.15, PYLON_HEIGHT * 0.66),
            parent=plinth, location=(x, y, PYLON_HEIGHT * 0.44),
            material=mats["glow"],
        )
        studio.bevel(trunk, width=0.012)

    collar = studio.cylinder(
        "Collar", radius_bottom=0.3, radius_top=0.38, height=0.32, segments=12,
        parent=plinth, location=(0.0, 0.0, PYLON_HEIGHT), material=mats["dark"],
    )
    studio.bevel(collar, width=0.02)

    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_Z))

    head = studio.wedge(
        "TurretHead", size=(0.86, 0.9, 0.62),
        parent=turret, material=mats["hull"], taper=0.72,
    )
    studio.bevel(head, width=0.03)

    tail = studio.box(
        "Counterweight", size=(0.34, 0.5, 0.56),
        parent=turret, location=(0.0, 0.56, -0.02), material=mats["dark"],
    )
    studio.bevel(tail, width=0.025)

    # --- the single emitter ----------------------------------------------
    # Short and very fat. This is the branch's whole silhouette.
    barrel = studio.cylinder(
        "Barrel", radius_bottom=0.3, radius_top=0.4, height=BARREL_LENGTH,
        segments=10, parent=turret,
        location=(0.0, -(BARREL_LENGTH * 0.5 + 0.32), -0.02),
        material=mats["dark"], base_at_origin=False,
    )
    barrel.rotation_euler = (1.5708, 0.0, 0.0)
    studio.bevel(barrel, width=0.02)

    # The lens. The brightest single face on any tower in the game, and the
    # thing the eye should land on first.
    studio.cylinder(
        "Muzzle", radius_bottom=0.42, radius_top=0.38, height=0.14, segments=10,
        parent=barrel, location=(0.0, 0.0, BARREL_LENGTH * 0.5 + 0.02),
        material=mats["accent"], base_at_origin=False,
    )
    studio.cylinder(
        "AccentLens", radius_bottom=0.31, radius_top=0.29, height=0.08, segments=10,
        parent=barrel, location=(0.0, 0.0, BARREL_LENGTH * 0.5 + 0.1),
        material=mats["glow"], base_at_origin=False,
    )

    # Focus vanes gripping the emitter housing.
    for index, x, y, angle in _tier.radial(4, 0.36, start_deg=45.0):
        vane = studio.box(
            "AccentVane%d" % (index + 1), size=(0.09, 0.09, 0.5),
            parent=barrel, location=(x, y, -0.06), material=mats["accent"],
        )
        studio.bevel(vane, width=0.01)

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
