"""Line Walker - the baseline. Medium armour, no strengths, no weaknesses.

The hardest of the four to design, because its job is to be unremarkable. It
has to read as "the normal one" so that the drone reads as fast and the brute
reads as heavy by comparison. Everything here is deliberately mid: mid height,
mid width, upright, walking on legs rather than hovering or grinding.

Output: data/models/enemies/walker.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/enemies/walker.glb"

RADIUS = 0.45
HEIGHT = 1.1


def build():
    studio.reset_scene()

    shell = studio.material("Shell", (0.8, 0.35, 0.4), metallic=0.3, roughness=0.5)
    glow = studio.material("Glow", (1.0, 0.75, 0.5), emission=1.2, roughness=0.3)
    dark = studio.material("Dark", (0.22, 0.13, 0.15), metallic=0.35, roughness=0.6)

    root = studio.empty("Walker")

    # Legs. Two angled struts rather than anything articulated - at this size
    # and camera distance, articulation is invisible and animation is a cost
    # this project has not paid for yet.
    # Lifted from 0.24 to 0.30 of the height: at the lower value the tilted leg
    # dipped to z = -0.08 and clipped through the ground plane.
    leg = studio.box(
        "Leg", size=(0.14, 0.16, HEIGHT * 0.5),
        parent=root, location=(0.22, 0.0, HEIGHT * 0.30), material=dark,
    )
    leg.rotation_euler = (0.0, math.radians(-7.0), 0.0)
    studio.mirror_x(leg, about=root)
    studio.bevel(leg, width=0.012)

    foot = studio.box(
        "Foot", size=(0.2, 0.34, 0.08),
        parent=root, location=(0.24, -0.02, 0.04), material=dark,
    )
    studio.mirror_x(foot, about=root)
    studio.bevel(foot, width=0.01)

    # Torso: a faceted slab, tilted very slightly forward so it looks like it is
    # advancing rather than standing.
    body = studio.sphere(
        "Body", radius=RADIUS, subdivisions=1,
        parent=root, location=(0.0, 0.0, HEIGHT * 0.68), material=shell,
        scale=(0.9, 0.78, 1.0),
    )
    body.rotation_euler = (math.radians(-8.0), 0.0, 0.0)
    studio.bevel(body, width=0.018)

    # Shoulder plates. The one piece of visual weight, so the eye has somewhere
    # to land at distance.
    pauldron = studio.box(
        "Pauldron", size=(0.2, 0.34, 0.16),
        parent=body, location=(0.4, 0.02, 0.16), material=dark,
    )
    pauldron.rotation_euler = (0.0, math.radians(22.0), 0.0)
    studio.mirror_x(pauldron, about=body)
    studio.bevel(pauldron, width=0.012)

    # Single forward eye.
    studio.sphere(
        "Eye", radius=0.1, subdivisions=1,
        parent=body, location=(0.0, -0.36, 0.08), material=glow,
        scale=(1.4, 0.7, 0.7),
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
