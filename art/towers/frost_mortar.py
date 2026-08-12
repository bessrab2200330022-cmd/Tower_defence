"""Frost Mortar - lobbed chilling shells.

From data/towers/frost_mortar.tres: 150 credits, 90-tick interval, explosive
damage, 3.0 splash radius, 40% slow for 120 ticks, and the only tower that
fires a travelling projectile rather than hitscan.

Its identity is area control, not damage, so the read is squat and heavy with a
short fat tube angled up. The upward tilt is the important bit: it is the only
visual cue that this tower arcs its shot rather than shooting straight, which
is what explains the travel time to a player who has never read a tooltip.

Build:  blender -b --python art/towers/frost_mortar.py
Output: data/models/towers/frost_mortar.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/towers/frost_mortar.glb"

BODY_HEIGHT = 1.3
# Longer and thinner than the first pass. At 1.0 long and 0.25 radius the tube
# read as a ball sitting on a drum rather than as a weapon.
BARREL_LENGTH = 1.2

DRUM_HEIGHT = BODY_HEIGHT * 0.46
COLLAR_HEIGHT = BODY_HEIGHT * 0.18
TURRET_PIVOT_Z = DRUM_HEIGHT + COLLAR_HEIGHT + 0.16

# Tube elevation. Enough to read as "lobs", not so much that the muzzle
# disappears behind the housing from the RTS camera angle.
TUBE_PITCH = math.radians(34.0)


def build():
    studio.reset_scene()

    hull = studio.material("Hull", (0.55, 0.58, 0.62), metallic=0.3, roughness=0.55)
    # Emission kept low: at 0.9 the muzzle ring blew out to pure white and
    # became the whole silhouette.
    trim = studio.material("Trim", (0.7, 0.9, 1.0), metallic=0.2, roughness=0.25,
                           emission=0.35)
    dark = studio.material("Dark", (0.15, 0.19, 0.22), metallic=0.25, roughness=0.7)

    root = studio.empty("FrostMortar")

    # --- Base -------------------------------------------------------------
    # The widest footprint of the three towers. It should look planted.
    pad = studio.prism("Base", radius=0.86, height=0.16, segments=8,
                       parent=root, material=dark)
    studio.bevel(pad, width=0.025)

    # Named "Plinth", not "Drum": game/views/tower_view.gd tints BODY_PARTS =
    # ["Base", "Plinth", "TurretHead"] by NAME, and anything unlisted keeps its
    # exported material. Called "Drum" this - the tower's whole body mass - never
    # received TowerDef.body_color, and the Hull colour above had been hand-tinted
    # teal to hide it. Do not rename it back.
    drum = studio.cylinder(
        "Plinth", radius_bottom=0.72, radius_top=0.66,
        height=DRUM_HEIGHT, segments=10,
        parent=pad, location=(0.0, 0.0, 0.14), material=hull,
    )
    studio.bevel(drum, width=0.03)

    # Coolant tanks around the drum. Rounded against the tower's flat faces so
    # the "this one is different" read survives being half-hidden behind others.
    tank = studio.cylinder(
        "CoolantTank", radius_bottom=0.17, radius_top=0.17, height=0.5, segments=8,
        parent=drum, location=(0.62, 0.34, 0.1), material=trim,
    )
    studio.mirror_x(tank, about=drum)
    studio.bevel(tank, width=0.02)

    collar = studio.cylinder(
        "Collar", radius_bottom=0.44, radius_top=0.48,
        height=COLLAR_HEIGHT, segments=12,
        parent=drum, location=(0.0, 0.0, DRUM_HEIGHT), material=dark,
    )
    studio.bevel(collar, width=0.02)

    # --- Turret -----------------------------------------------------------
    turret = studio.empty("Turret", parent=root, location=(0.0, 0.0, TURRET_PIVOT_Z))

    # Low, wide cradle. The turret is broad rather than tall - the opposite
    # proportion to the Plasma Lance, on purpose.
    head = studio.wedge(
        "TurretHead", size=(0.94, 0.72, 0.38),
        parent=turret, material=hull, taper=0.72,
    )
    studio.bevel(head, width=0.03)

    # Shell rack at the back, reading as ammunition rather than machinery.
    tail = studio.box(
        "Counterweight", size=(0.62, 0.26, 0.34),
        parent=turret, location=(0.0, 0.44, 0.02), material=dark,
    )
    studio.bevel(tail, width=0.02)

    # Trunnion blocks: the pivots the tube visibly hinges on. Small, but they
    # are what makes the tilt look mechanical rather than like a modelling error.
    trunnion = studio.cylinder(
        "Trunnion", radius_bottom=0.13, radius_top=0.13, height=0.16, segments=8,
        parent=turret, location=(0.4, -0.06, 0.06), material=dark,
        base_at_origin=False,
    )
    trunnion.rotation_euler = (0.0, 1.5708, 0.0)
    studio.mirror_x(trunnion, about=turret)
    studio.bevel(trunnion, width=0.015)

    # --- Barrel -----------------------------------------------------------
    # Short fat tube, pitched up. Named Barrel because tower_view.gd slides this
    # node on recoil; the pitch lives on the node, and recoil still runs along
    # the turret's forward axis, which reads correctly for a mortar.
    barrel = studio.cylinder(
        "Barrel", radius_bottom=0.2, radius_top=0.23,
        height=BARREL_LENGTH, segments=10,
        parent=turret,
        location=(0.0, -(BARREL_LENGTH * 0.32), 0.14),
        material=hull, base_at_origin=False,
    )
    # +Z of the tube becomes forward-and-up once pitched.
    barrel.rotation_euler = (1.5708 - TUBE_PITCH, 0.0, 0.0)
    studio.bevel(barrel, width=0.02)

    # Frost ring at the mouth. This is where spawn_muzzle_flash lands, so it
    # wants to be the brightest thing on the model.
    muzzle = studio.cylinder(
        "Muzzle", radius_bottom=0.25, radius_top=0.27, height=0.1, segments=10,
        parent=barrel, location=(0.0, 0.0, BARREL_LENGTH * 0.5),
        material=trim, base_at_origin=False,
    )
    studio.bevel(muzzle, width=0.015)

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
