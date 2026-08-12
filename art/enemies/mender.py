"""Mender - the healer. 1,800 HP, speed 4.5, Medium armour.

docs/design/enemies.md: HEAL_PULSE every 120 ticks, 300 HP to allies within
4.5. "Focus it first, or fight the same walkers twice."

The design problem is specific and nasty: the Mender marches BURIED IN A WALKER
COLUMN (wave 9), it is Medium armour like the Walker, it moves at 4.5 like the
Walker, and it is only 100 HP heavier. Every stat it has is a Walker's. If the
model is also a Walker's, the wave is unplayable without the 2.3 targeting UI.

So this model is drawn against the Walker, feature by feature, rather than
against the brief in isolation:

    Walker              Mender
    upright, on legs    hunched, wide splayed stance
    hard shoulder       open emitter dish where the shoulders would be
      pauldrons
    single eye          twin low sensors
    warm red            same red family, pinker and lighter in value
    warm amber glow     GREEN glow

The green is the one place in this roster where a hue break is worth its cost.
Armour type is carried by body colour (Medium = red) and stays carried by it;
the glow is a second channel, and healing reads green to every player alive.
It also pre-stains the pulse ring A4 will draw off ENEMY_HEALED in the same
colour, so the ring and its source are obviously one machine.

The dish is the other half of that: the pulse has to LOOK like it comes from
somewhere. A flat-topped machine emitting a ring reads as a bug.

Output: data/models/enemies/mender.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/enemies/mender.glb"

RADIUS = 0.50
# The Mender must stand clear of the Walker column it hides in. The Walker's
# def says 1.3 (its model only reaches 1.173 - see the F3 finding), so 1.43
# keeps a visible head of clearance even after the Walker is corrected, while
# staying under the Warden's 1.55 so the two supports do not trade places.
HEIGHT = 1.43


def build():
    studio.reset_scene()

    # Medium armour reads red (Walker 0.8/0.35/0.4). Pinker and a step lighter,
    # so a Mender inside a Walker column separates by value as well as by shape.
    shell = studio.material("Shell", (0.78, 0.42, 0.5), metallic=0.3, roughness=0.5)
    # The exception to the palette. See the docstring.
    glow = studio.material("Glow", (0.55, 1.0, 0.62), emission=1.7, roughness=0.25)
    dark = studio.material("Dark", (0.2, 0.14, 0.16), metallic=0.35, roughness=0.6)

    root = studio.empty("Mender")

    # Legs splayed OUTWARD - the Walker's rake inward. A wide stance under a
    # narrow body is the fastest silhouette difference available at distance.
    leg = studio.box(
        "Leg", size=(0.14, 0.17, 0.56),
        parent=root, location=(0.26, 0.02, 0.31), material=dark,
    )
    leg.rotation_euler = (0.0, math.radians(13.0), 0.0)
    studio.mirror_x(leg, about=root)
    studio.bevel(leg, width=0.012)

    foot = studio.box(
        "Foot", size=(0.24, 0.32, 0.08),
        parent=root, location=(0.33, 0.0, 0.05), material=dark,
    )
    studio.mirror_x(foot, about=root)
    studio.bevel(foot, width=0.01)

    # Rear stabiliser. A third contact point says "this thing is a platform,
    # not a soldier" - and it fills the profile the Walker leaves empty.
    tail = studio.box(
        "Stabiliser", size=(0.14, 0.3, 0.36),
        # z=0.24: raked back 24 degrees this reached z = -0.021 at 0.20.
        parent=root, location=(0.0, 0.34, 0.24), material=dark,
    )
    tail.rotation_euler = (math.radians(-24.0), 0.0, 0.0)
    studio.bevel(tail, width=0.01)

    # Body: rounder and hunched forward. Tilted the opposite way to the Walker
    # so the two read differently even in pure silhouette.
    body = studio.sphere(
        "Body", radius=0.42, subdivisions=1,
        parent=root, location=(0.0, 0.0, 0.72), material=shell,
        scale=(1.0, 0.92, 0.98),
    )
    body.rotation_euler = (math.radians(10.0), 0.0, 0.0)
    studio.bevel(body, width=0.018)

    # Twin low sensors, where the Walker has one high one.
    sensor = studio.sphere(
        "Sensor", radius=0.075, subdivisions=1,
        parent=body, location=(0.15, -0.36, -0.04), material=glow,
        scale=(1.1, 0.7, 0.9),
    )
    studio.mirror_x(sensor, about=body)

    # Repair arms, folded forward and down over the front. They are what the
    # machine does, so they belong where the eye lands first.
    arm = studio.box(
        "Arm", size=(0.1, 0.44, 0.1),
        parent=root, location=(0.32, -0.26, 0.78), material=dark,
    )
    arm.rotation_euler = (math.radians(34.0), 0.0, math.radians(-10.0))
    studio.mirror_x(arm, about=root)
    studio.bevel(arm, width=0.01)

    # Emitter dish. Flares upward and outward - segments kept low so it stays
    # faceted and does not drift into the towers' machined-cylinder language.
    dish = studio.cylinder(
        "Dish", radius_bottom=0.24, radius_top=0.46, height=0.16, segments=8,
        parent=root, location=(0.0, 0.02, 1.12), material=shell,
    )
    studio.bevel(dish, width=0.014)

    # The pulse origin, sitting in the dish. This is the node the eye should
    # find when a heal fires.
    studio.sphere(
        "Core", radius=0.2, subdivisions=1,
        parent=root, location=(0.0, 0.02, 1.3), material=glow,
        scale=(1.0, 1.0, 0.62),
    )

    # Four short emitter posts around the dish rim, so the ring has visible
    # hardware behind it rather than appearing out of a smooth bowl.
    for index, degrees in enumerate((45.0, 135.0, 225.0, 315.0)):
        radians = math.radians(degrees)
        studio.box(
            "Post%d" % (index + 1), size=(0.06, 0.06, 0.2),
            parent=root,
            location=(math.cos(radians) * 0.38, 0.02 + math.sin(radians) * 0.38, 1.33),
            material=dark,
        )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
