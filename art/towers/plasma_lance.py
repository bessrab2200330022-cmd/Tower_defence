"""Plasma Lance - the long-range energy beam.

From data/towers/plasma_lance.tres: 190 credits, 13.0 range, 66-tick interval,
energy damage, Strongest targeting. It is the expensive answer to shielded and
heavy targets, and the player buys one or two, not eight.

So it should read as the opposite of the Arc Cannon in every dimension: tall
where that is squat, slender where that is chunky, one long emitter instead of
twin stubby barrels. If a player can't tell them apart in a crowded lane at a
glance, the tower has failed at its job before balance even enters into it.

Build:  blender -b --python art/towers/plasma_lance.py
Output: data/models/towers/plasma_lance.glb
"""

import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/towers/plasma_lance.glb"

BODY_HEIGHT = 2.0
BARREL_LENGTH = 1.6

PYLON_HEIGHT = BODY_HEIGHT * 0.66
COLLAR_HEIGHT = BODY_HEIGHT * 0.14
TURRET_PIVOT_Z = PYLON_HEIGHT + COLLAR_HEIGHT + 0.14


def build():
    studio.reset_scene()

    hull = studio.material("Hull", (0.55, 0.58, 0.62), metallic=0.4, roughness=0.42)
    trim = studio.material("Trim", (0.55, 0.85, 1.0), metallic=0.3, roughness=0.25,
                           emission=1.6)
    dark = studio.material("Dark", (0.14, 0.15, 0.19), metallic=0.25, roughness=0.65)

    root = studio.empty("PlasmaLance")

    # --- Base -------------------------------------------------------------
    # Narrower pad than the Arc Cannon. This tower should look like it needs
    # less ground and more sky.
    pad = studio.prism("Base", radius=0.7, height=0.18, segments=6,
                       parent=root, material=dark)
    studio.bevel(pad, width=0.02)

    # Hexagonal pylon, tapering hard. The taper is what sells the height.
    # Named "Plinth" and not "Pylon" on purpose: tower_view.gd tints BODY_PARTS =
    # ["Base", "Plinth", "TurretHead"] by NAME. As "Pylon" this shaft - 66% of the
    # tower's height - never received TowerDef.body_color, and the Hull colour was
    # hand-tinted violet to compensate. Do not rename it back.
    pylon = studio.cylinder(
        "Plinth", radius_bottom=0.46, radius_top=0.26,
        height=PYLON_HEIGHT, segments=6,
        parent=pad, location=(0.0, 0.0, 0.16), material=hull,
    )
    studio.bevel(pylon, width=0.025)

    # Three glowing capacitor rods up the shaft. Energy weapons need to look
    # charged when they are idle, or the long reload reads as "broken".
    rod = studio.box(
        "Capacitor", size=(0.1, 0.1, PYLON_HEIGHT * 0.55),
        parent=pylon, location=(0.36, 0.0, PYLON_HEIGHT * 0.42), material=trim,
    )
    studio.mirror_x(rod, about=pylon)
    studio.bevel(rod, width=0.012)

    rod_back = studio.box(
        "CapacitorRear", size=(0.1, 0.1, PYLON_HEIGHT * 0.55),
        parent=pylon, location=(0.0, 0.36, PYLON_HEIGHT * 0.42), material=trim,
    )
    studio.bevel(rod_back, width=0.012)

    collar = studio.cylinder(
        "Collar", radius_bottom=0.24, radius_top=0.3,
        height=COLLAR_HEIGHT, segments=12,
        parent=pylon, location=(0.0, 0.0, PYLON_HEIGHT), material=dark,
    )
    studio.bevel(collar, width=0.015)

    # --- Turret -----------------------------------------------------------
    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_PIVOT_Z))

    # Compact yoke rather than a big head: the mass is in the emitter, not the
    # housing, which is what makes it read as a lance and not a cannon.
    head = studio.wedge(
        "TurretHead", size=(0.62, 0.66, 0.46),
        parent=turret, material=hull, taper=0.5,
    )
    studio.bevel(head, width=0.025)

    # Focusing fins either side, angled back. Cheap way to imply the beam is
    # being shaped rather than just fired.
    fin = studio.box(
        "Fin", size=(0.07, 0.6, 0.42),
        parent=turret, location=(0.36, 0.06, 0.06), material=dark,
    )
    fin.rotation_euler = (0.0, 0.0, -0.22)
    studio.mirror_x(fin, about=turret)
    studio.bevel(fin, width=0.015)

    # Heat sink stack at the back.
    tail = studio.box(
        "Counterweight", size=(0.42, 0.36, 0.44),
        parent=turret, location=(0.0, 0.5, -0.02), material=dark,
    )
    studio.bevel(tail, width=0.02)

    # --- Barrel -----------------------------------------------------------
    # A single long emitter, hexagonal so it catches light along its length.
    barrel = studio.cylinder(
        "Barrel", radius_bottom=0.13, radius_top=0.1,
        height=BARREL_LENGTH, segments=6,
        parent=turret,
        location=(0.0, -(BARREL_LENGTH * 0.5 + 0.28), 0.02),
        material=hull, base_at_origin=False,
    )
    barrel.rotation_euler = (1.5708, 0.0, 0.0)  # lay the tube along -Y
    studio.bevel(barrel, width=0.012)

    # Emitter ring at the tip: the bright point the eye tracks when it fires.
    # Local +Z of the barrel points forward after its X rotation, so the tip is
    # at +half-length, not minus.
    muzzle = studio.cylinder(
        "Muzzle", radius_bottom=0.2, radius_top=0.16, height=0.18, segments=8,
        parent=barrel, location=(0.0, 0.0, BARREL_LENGTH * 0.5),
        material=trim, base_at_origin=False,
    )
    studio.bevel(muzzle, width=0.012)

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
