"""Courser - the sprinter. 500 HP, speed 9.5, Light armour.

Design brief, docs/design/enemies.md: "lowest silhouette in the game,
forward-raked, visible dust/thrust trail. Speed must read from the model
standing still." That last clause is the whole problem. A tower defence enemy
is seen for eight seconds from forty units up; there is no animation budget and
no time for the player to infer speed from motion, because by the time they
have inferred it the Courser is at the Anchor.

So speed is built into the pose. Three devices, in order of how far away they
still read:

  1. Length. At 1.28 units nose to tail it is the longest enemy in the game on
     a body only 0.5 wide. Nothing else in the roster has that aspect ratio -
     the Drone is 1.35x its width, this is nearer 2.6x.
  2. Rake. The whole hull pitches nose-down 6 degrees. A level body reads as
     parked no matter how streamlined it is.
  3. Sweep. Canards and skids all trail backwards. Every edge on this thing
     points at where it came from.

It does NOT hover. The Drone already owns hovering, and two hovering Light
enemies in the same lane would collapse into one silhouette at distance - which
is exactly the readability failure enemies.md 6 is written to prevent. The
Courser plants two skids and planes along the ground instead.

Output: data/models/enemies/courser.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/enemies/courser.glb"

# Matches the radius/height proposed for courser.tres in art/PENDING.md.
# The health bar hangs at height + 0.45, so the crown has to land near HEIGHT
# or the bar floats. Verified with a bounding-box pass after every change.
RADIUS = 0.40
# 0.53 is chosen against the Drone's measured crown of 0.581, not picked for
# roundness: enemies.md requires the Courser be the LOWEST silhouette in the
# game, and the first build came out at 0.591 - taller than the Drone, brief
# quietly broken. Anything that raises this number has to lower the Drone.
HEIGHT = 0.53

RAKE_DEG = 6.0


def build():
    studio.reset_scene()

    # Light armour reads orange across the roster (Drone 0.9/0.5/0.35). The
    # Courser sits hotter and more saturated so the two separate in a mixed
    # wave-7 pack without relying on the shape read alone.
    shell = studio.material("Shell", (0.95, 0.58, 0.3), metallic=0.3, roughness=0.45)
    glow = studio.material("Glow", (1.0, 0.85, 0.45), emission=1.6, roughness=0.3)
    dark = studio.material("Dark", (0.2, 0.13, 0.11), metallic=0.35, roughness=0.6)

    root = studio.empty("Courser")

    hull_z = 0.30

    # Hull. Stretched hard along Y - the travel axis - and squashed in Z. The
    # icosphere keeps it in the enemy shape family; the scaling is what makes
    # it a dart rather than a pebble.
    body = studio.sphere(
        "Body", radius=0.30, subdivisions=1,
        parent=root, location=(0.0, 0.0, hull_z), material=shell,
        scale=(0.82, 2.05, 0.58),
    )
    # Positive X rotation drops the -Y end, which is Godot's forward. Nose down.
    body.rotation_euler = (math.radians(RAKE_DEG), 0.0, 0.0)
    studio.bevel(body, width=0.016)

    # Nose spike. Narrow, bright, and the furthest-forward thing on the model,
    # so a Courser coming at the camera still has a point.
    studio.sphere(
        "Nose", radius=0.11, subdivisions=1,
        parent=body, location=(0.0, -0.56, -0.03), material=glow,
        scale=(0.7, 1.9, 0.7),
    )

    # Canards, swept back 34 degrees. Mirrored about the ROOT, not about
    # themselves - see art/README.md, this is the single-barrelled-cannon trap.
    canard = studio.box(
        "Canard", size=(0.34, 0.5, 0.05),
        parent=root, location=(0.28, -0.12, hull_z + 0.02), material=dark,
    )
    canard.rotation_euler = (0.0, math.radians(-12.0), math.radians(-34.0))
    studio.mirror_x(canard, about=root)
    studio.bevel(canard, width=0.01)

    # Dorsal blade. Sets the crown height and gives the top-down view - which
    # is most of them - a directional line to read.
    blade = studio.box(
        "Blade", size=(0.06, 0.62, 0.2),
        parent=root, location=(0.0, 0.1, hull_z + 0.095), material=dark,
    )
    blade.rotation_euler = (math.radians(RAKE_DEG), 0.0, 0.0)
    studio.bevel(blade, width=0.01)

    # Skids. Angled so the contact patch is at the back: the machine looks like
    # it is about to be somewhere else.
    skid = studio.box(
        "Skid", size=(0.07, 0.66, 0.12),
        # z=0.14, not 0.09: a 0.66-long skid raked 14 degrees drops its nose
        # 0.08 below its origin, and at 0.09 the tip sank to z = -0.046 and
        # clipped through the board. Bounding-box pass caught it.
        parent=root, location=(0.23, 0.1, 0.14), material=dark,
    )
    skid.rotation_euler = (math.radians(14.0), 0.0, 0.0)
    studio.mirror_x(skid, about=root)
    studio.bevel(skid, width=0.008)

    # Thruster at the tail. The Drone has one too; on the Courser it is twice
    # the size relative to the body, because this is the enemy whose entire
    # identity is the engine.
    studio.sphere(
        "Thruster", radius=0.14, subdivisions=1,
        parent=root, location=(0.0, 0.6, hull_z + 0.07), material=glow,
        scale=(1.1, 0.55, 0.85),
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
