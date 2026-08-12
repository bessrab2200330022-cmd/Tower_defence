"""Skiff - the flier. 900 HP, speed 6.0, Light armour.

docs/design/enemies.md: "altitude IS the identity; nothing else flies."

That sentence decides the model. Everything else in the roster touches the
ground, so the Skiff does not need to look aerodynamic, or fast, or armoured -
it needs to look SUSPENDED. The readable fact is the gap of empty air under it,
and the model is built so that gap exists even if the view layer never lifts it:
the lowest geometry sits at z = 0.42, so a Skiff dropped on the path by a build
that has not shipped ROADMAP 2.5 yet still visibly floats. That is deliberate.
An enemy whose whole point is the air lane must never render as if it walked.

The second job is fiction. The Reclamation is a salvage swarm, and this is the
only machine in the roster with a reason to carry anything - so it flies a
slung grapple under a flat lifting hull. It reads as a lifter, not a gunship,
which is honest: the Skiff has no attack, it just gets to the Anchor.

Mortars cannot target air at any tier (upgrades.md 6) and this enemy is what
collects that debt.

Output: data/models/enemies/skiff.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/enemies/skiff.glb"

RADIUS = 0.55
HEIGHT = 1.0

# Built-in float. The air lane will add real cruise altitude on top of this;
# this is only the guarantee that the model never reads as grounded. The real
# cruise height is A3's number and is not specified anywhere yet - flagged in
# art/PENDING.md.
FLOOR = 0.42


def build():
    studio.reset_scene()

    # Light armour, so the orange family - but paled and desaturated toward the
    # sky. Against a green board a lighter value separates from the Drone and
    # the Courser without leaving the hue the armour table implies.
    shell = studio.material("Shell", (0.88, 0.55, 0.42), metallic=0.3, roughness=0.5)
    glow = studio.material("Glow", (1.0, 0.8, 0.5), emission=1.5, roughness=0.3)
    dark = studio.material("Dark", (0.19, 0.15, 0.16), metallic=0.35, roughness=0.6)

    root = studio.empty("Skiff")

    hull_z = FLOOR + 0.26

    # Flat delta hull. Wide and thin: seen from the RTS camera the Skiff is
    # mostly a plan view, so the silhouette that matters is the one from above.
    body = studio.sphere(
        "Body", radius=0.34, subdivisions=1,
        parent=root, location=(0.0, 0.0, hull_z), material=shell,
        scale=(1.5, 1.75, 0.5),
    )
    studio.bevel(body, width=0.018)

    # Cockpit blister forward, so it has a front from above as well as in
    # profile - the angle it will actually be seen from.
    studio.sphere(
        "Sensor", radius=0.13, subdivisions=1,
        parent=body, location=(0.0, -0.42, 0.1), material=glow,
        scale=(1.0, 1.2, 0.8),
    )

    # Lift pods, one per side, lying on their sides. These are the "why does it
    # fly" - a hull with no visible lift reads as a hovering brick.
    pod = studio.cylinder(
        "LiftPod", radius_bottom=0.15, radius_top=0.13, height=0.46, segments=10,
        parent=root, location=(0.56, -0.04, hull_z + 0.04), material=dark,
        base_at_origin=False,
    )
    pod.rotation_euler = (0.0, math.radians(90.0), 0.0)
    studio.mirror_x(pod, about=root)
    studio.bevel(pod, width=0.012)

    # Intake glow on the underside of each pod. Downward-facing light is the
    # cheapest possible "this is what holds it up".
    intake = studio.sphere(
        "Intake", radius=0.1, subdivisions=1,
        parent=root, location=(0.56, -0.04, hull_z - 0.1), material=glow,
        scale=(1.0, 1.0, 0.45),
    )
    studio.mirror_x(intake, about=root)

    # Tail fins, swept up and back.
    fin = studio.box(
        "Fin", size=(0.05, 0.3, 0.26),
        parent=root, location=(0.22, 0.5, hull_z + 0.14), material=dark,
    )
    fin.rotation_euler = (math.radians(-16.0), math.radians(14.0), 0.0)
    studio.mirror_x(fin, about=root)
    studio.bevel(fin, width=0.008)

    # Slung grapple. Hangs into the empty air under the hull, which is the
    # point: it draws the eye down into the gap that says "flying".
    spar = studio.box(
        "Spar", size=(0.08, 0.08, 0.2),
        parent=root, location=(0.0, 0.06, FLOOR + 0.14), material=dark,
    )
    studio.bevel(spar, width=0.008)

    claw = studio.box(
        "Claw", size=(0.1, 0.34, 0.1),
        parent=root, location=(0.16, 0.06, FLOOR + 0.03), material=dark,
    )
    claw.rotation_euler = (0.0, math.radians(28.0), 0.0)
    studio.mirror_x(claw, about=root)
    studio.bevel(claw, width=0.008)

    # Mast. Sets the crown so the health bar has something to sit over.
    studio.box(
        "Mast", size=(0.06, 0.06, 0.22),
        parent=root, location=(0.0, 0.2, hull_z + 0.2), material=dark,
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
