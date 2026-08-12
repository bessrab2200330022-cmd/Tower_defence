"""Scout Drone - fast, fragile, light armour, arrives in swarms.

Contract with game/views/enemy_view.gd: the model's origin sits on the ground
and it extends up to roughly EnemyDef.height, so the procedural health bar
lands above it. Node names do not matter for enemies - nothing animates them
individually - but a node called Body is used for the chilled squash.

Enemies are icospheres and angled slabs where towers are prisms and boxes. That
silhouette split is doing real work: at RTS distance, in a crowded lane, shape
family tells you what is yours and what is coming to kill you faster than
colour does.

Output: data/models/enemies/drone.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/enemies/drone.glb"

RADIUS = 0.35
HEIGHT = 0.8


def build():
    studio.reset_scene()

    shell = studio.material("Shell", (0.9, 0.5, 0.35), metallic=0.25, roughness=0.5)
    glow = studio.material("Glow", (1.0, 0.82, 0.4), emission=1.4, roughness=0.3)
    dark = studio.material("Dark", (0.2, 0.14, 0.13), metallic=0.3, roughness=0.6)

    root = studio.empty("Drone")

    # Hovers. The gap under it is the cheapest possible "this thing is fast"
    # signal and it costs one number.
    hover_z = HEIGHT * 0.42

    body = studio.sphere(
        "Body", radius=RADIUS, subdivisions=1,
        parent=root, location=(0.0, 0.0, hover_z), material=shell,
        scale=(1.0, 1.35, 0.7),   # stretched along travel, flattened vertically
    )
    studio.bevel(body, width=0.015)

    # Forward sensor. Gives the drone a nose, so a swarm reads as facing one way
    # rather than as a bag of pebbles.
    studio.sphere(
        "Sensor", radius=0.12, subdivisions=1,
        parent=body, location=(0.0, -0.42, 0.02), material=glow,
    )

    # Swept wing pods either side.
    pod = studio.box(
        "Pod", size=(0.3, 0.14, 0.07),
        parent=root, location=(0.36, 0.06, hover_z), material=dark,
    )
    pod.rotation_euler = (0.0, 0.0, math.radians(18.0))
    studio.mirror_x(pod, about=root)
    studio.bevel(pod, width=0.01)

    # Thruster glow at the back, so it reads from behind as it runs away
    # from your towers toward the goal.
    studio.sphere(
        "Thruster", radius=0.09, subdivisions=1,
        parent=root, location=(0.0, 0.42, hover_z), material=glow,
        scale=(1.0, 0.6, 1.0),
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
