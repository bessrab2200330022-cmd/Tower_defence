"""Arc Cannon - the cheap, fast-firing kinetic turret.

Read the design brief off data/towers/arc_cannon.tres: 90 credits, 24-tick fire
interval, kinetic damage, shortest range of the three. It is the tower a player
buys eight of, so its job on screen is to read instantly at RTS camera distance
and to look busy when it fires. Twin stubby barrels and a fat ammo drum say
"fast and cheap" faster than any amount of surface detail would.

Node contract with game/views/tower_view.gd:
    Base    - static, sits on the ground, origin at y=0
    Turret  - pivot only, rotated on Y to face the target
    Barrel  - child of Turret, slid along +Z for recoil

Build:  blender -b --python art/towers/arc_cannon.py
Output: data/models/towers/arc_cannon.glb
"""

import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

# Read by art/reload.py and art/build_all.py. Relative to the repo root.
OUTPUT_PATH = "data/models/towers/arc_cannon.glb"

# Matches TowerDef.body_height / barrel_length so the sim's range ring, the
# ghost preview and the model all agree.
BODY_HEIGHT = 1.5
BARREL_LENGTH = 1.2

# Proportions. The first pass made the base 72% of the height and the turret
# looked like a hat on a bollard - at RTS camera distance the moving part was
# the part you couldn't see. Weighting it the other way reads far better: a
# narrow plinth, a chunky turret.
PLINTH_HEIGHT = BODY_HEIGHT * 0.54
COLLAR_HEIGHT = BODY_HEIGHT * 0.20
TURRET_PIVOT_Z = PLINTH_HEIGHT + COLLAR_HEIGHT + 0.12


def build():
    studio.reset_scene()

    hull = studio.material("Hull", (0.55, 0.58, 0.62), metallic=0.35, roughness=0.5)
    trim = studio.material("Trim", (0.85, 0.72, 0.35), metallic=0.5, roughness=0.4)
    dark = studio.material("Dark", (0.16, 0.17, 0.20), metallic=0.2, roughness=0.7)

    root = studio.empty("ArcCannon")

    # --- Base -------------------------------------------------------------
    # A wide ground pad reads as "bolted down" and stops the tower looking like
    # it is balanced on a point when seen from above - which is most of the time.
    pad = studio.cylinder(
        "Base", radius_bottom=0.8, radius_top=0.74, height=0.16, segments=8,
        parent=root, material=dark,
    )
    studio.bevel(pad, width=0.02)

    # Octagonal plinth: machined rather than turned, and the flat faces catch
    # light differently from the round enemies, which helps them separate.
    plinth = studio.cylinder(
        "Plinth", radius_bottom=0.6, radius_top=0.44,
        height=PLINTH_HEIGHT, segments=8,
        parent=pad, location=(0.0, 0.0, 0.14), material=hull,
    )
    studio.bevel(plinth, width=0.03)

    # Recessed collar: the visual joint that makes the rotating half look like
    # it belongs to the static half rather than resting on it.
    collar = studio.cylinder(
        "Collar", radius_bottom=0.34, radius_top=0.38,
        height=COLLAR_HEIGHT, segments=12,
        parent=plinth, location=(0.0, 0.0, PLINTH_HEIGHT), material=dark,
    )
    studio.bevel(collar, width=0.02)

    # Buttresses, mirrored across X. Break the cone silhouette at ground level.
    strut = studio.box(
        "Strut", size=(0.16, 0.5, 0.44),
        parent=plinth, location=(0.52, 0.0, 0.2), material=dark,
    )
    studio.mirror_x(strut, about=plinth)
    studio.bevel(strut, width=0.02)

    # --- Turret -----------------------------------------------------------
    # Pivot node only. tower_view.gd sets rotation.y here; geometry must not
    # live on the pivot itself or the recoil offsets get double-applied.
    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_PIVOT_Z))

    # Deliberately larger than the plinth is wide. The turret is the part that
    # moves, so it should be the part that carries the read.
    head = studio.wedge(
        "TurretHead", size=(0.9, 0.94, 0.52),
        parent=turret, material=hull, taper=0.58,
    )
    studio.bevel(head, width=0.03)

    # Counterweight at the back. Gives the turret a front and a back from every
    # angle, so facing is legible even when the barrels point away from camera.
    tail = studio.box(
        "Counterweight", size=(0.54, 0.3, 0.4),
        parent=turret, location=(0.0, 0.56, -0.02), material=dark,
    )
    studio.bevel(tail, width=0.02)

    # Ammo drum on the left flank. The asymmetry is the point: it reads as
    # "feeds a lot of rounds fast", which is this tower's whole identity.
    drum = studio.cylinder(
        "AmmoDrum", radius_bottom=0.24, radius_top=0.24, height=0.34, segments=10,
        parent=turret, location=(-0.62, 0.14, 0.04), material=trim,
        base_at_origin=False,
    )
    drum.rotation_euler = (0.0, 1.5708, 0.0)  # lie the drum on its side
    studio.bevel(drum, width=0.02)

    # Sight block on top, small and bright.
    studio.box(
        "Sight", size=(0.18, 0.2, 0.12),
        parent=turret, location=(0.0, 0.1, 0.3), material=trim,
    )

    # --- Barrel -----------------------------------------------------------
    # One object named "Barrel" because the view layer slides exactly that node
    # on recoil; the twin is a mirror modifier, not a second object.
    # Modelled along -Y, which the exporter turns into Godot's +Z.
    barrel = studio.box(
        "Barrel", size=(0.15, BARREL_LENGTH, 0.15),
        parent=turret,
        location=(0.21, -(BARREL_LENGTH * 0.5 + 0.34), -0.04),
        material=dark,
    )
    # Mirror about the turret, not the barrel: the barrel sits off-centre, so
    # mirroring about its own origin would just fold it onto itself.
    studio.mirror_x(barrel, about=turret)
    studio.bevel(barrel, width=0.015)

    # Muzzle brake: a wider block at the tip so the barrel ends in something
    # rather than just stopping, and so the gun still reads head-on.
    muzzle = studio.box(
        "Muzzle", size=(0.23, 0.2, 0.23),
        parent=barrel, location=(0.0, -(BARREL_LENGTH * 0.5 - 0.04), 0.0),
        material=trim,
    )
    studio.mirror_x(muzzle, about=turret)
    studio.bevel(muzzle, width=0.015)

    return root


if __name__ == "__main__":
    model = build()
    # Export before adding preview lighting, so the shipped .glb contains
    # nothing but the model.
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
