"""Frost Shell - the Frost Mortar's projectile.

The only travelling projectile in the game, so it is the only thing on screen
whose position the player can read ahead of. It needs to be visible against the
ground at RTS distance without being so bright it competes with the towers.

Modelled pointing along Blender -Y so it exports nose-forward along Godot +Z;
game/views/projectile_view.gd aims that axis down the direction of travel.

Output: data/models/projectiles/frost_shell.glb
"""

import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/projectiles/frost_shell.glb"

LENGTH = 0.44


def build():
    studio.reset_scene()

    casing = studio.material("Casing", (0.62, 0.8, 0.88), metallic=0.5, roughness=0.35)
    glow = studio.material("Glow", (0.75, 0.96, 1.0), emission=2.2, roughness=0.2)
    dark = studio.material("Dark", (0.16, 0.22, 0.28), metallic=0.4, roughness=0.5)

    root = studio.empty("FrostShell")

    # Body: a tapered cone, nose toward -Y.
    body = studio.cylinder(
        "Body", radius_bottom=0.11, radius_top=0.05,
        height=LENGTH, segments=8,
        parent=root, material=casing, base_at_origin=False,
    )
    body.rotation_euler = (-1.5708, 0.0, 0.0)  # +Z of the cone -> -Y
    studio.bevel(body, width=0.01)

    # Glowing core band, so it is trackable even when the casing is edge-on to
    # the light.
    studio.cylinder(
        "Core", radius_bottom=0.13, radius_top=0.13, height=0.09, segments=8,
        parent=body, location=(0.0, 0.0, -LENGTH * 0.12),
        material=glow, base_at_origin=False,
    )

    # Three tail fins. Cheap, and they make the thing read as aimed rather than
    # as a floating pebble.
    for index, angle in enumerate([0.0, 2.0944, 4.1888]):
        fin = studio.box(
            "Fin%d" % (index + 1), size=(0.02, 0.14, 0.16),
            parent=body, location=(0.0, 0.0, -LENGTH * 0.42), material=dark,
        )
        fin.rotation_euler = (0.0, 0.0, angle)

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
