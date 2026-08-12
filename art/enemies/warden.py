"""Warden - the shield aura. 2,600 HP, speed 4.0, Shielded armour.

docs/design/enemies.md: "AURA: living allies within 4.0 take 60% of computed
damage." Countered by killing it first, which Strongest targeting does for you
because 2,600 sits above the 2,400 Shielded Scouts it escorts.

So the model has exactly one job the stat block cannot do: make "kill that one"
visible BEFORE the player has learned to trust Strongest targeting. Wave 8
(Phalanx) is scripted so the Warden marches 30 ticks ahead of its escorts, and
the whole lesson lands only if the player can see which machine is the shepherd
while it is still walking toward them.

Height is how that is done. At 1.55 it stands half a body clear of the 1.1-tall
Scouts around it, and the mast is the tallest thing in any pack it appears in.
Bulk would not have worked - the Brute already owns bulk at 1.56, and a second
big machine would just read as another Brute.

The field globe on the mast head is the shell_node. It reuses the Shielded
Scout's exact mechanism (the model ships opaque, enemy_view.gd makes the named
node translucent) which is deliberate: shielded things in this game are
see-through, and the player learns that once. But it is a globe on a projector,
not a bubble around a body - the Warden protects OTHERS, and its silhouette
should say so.

    shell_node = "Field"

The mast is built as a separate collar and head so it can be spun view-side if
A4 ever wants the "rotating" the brief asks for. Nothing here animates.

Output: data/models/enemies/warden.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/enemies/warden.glb"

RADIUS = 0.52
# 1.46, not the 1.55 this was first built at. At 1.55 the field globe topped
# out at 1.556 against the Brute's measured 1.564 - a tie, and WORKSTREAMS
# names "the Brute must be visibly the tallest thing on the board" as one of
# the two things in this project that cannot be written down. 1.46 leaves the
# Brute a clear head while the Warden still stands 0.37 over the Shielded
# Scouts it escorts, which is the number the Phalanx lesson actually needs.
HEIGHT = 1.46

MAST_TOP = 1.135
HEAD_Z = 1.205


def build():
    studio.reset_scene()

    # Shielded armour is blue across the roster (Scout 0.35/0.75/0.9). The
    # Warden runs deeper and less cyan - it is the heavier shielded machine, and
    # the value difference keeps the two apart in a Phalanx pack.
    shell = studio.material("Shell", (0.3, 0.62, 0.85), metallic=0.35, roughness=0.45)
    field = studio.material("Field", (0.45, 0.85, 1.0), emission=0.9, roughness=0.25)
    glow = studio.material("Glow", (0.8, 0.98, 1.0), emission=1.8, roughness=0.2)
    dark = studio.material("Dark", (0.12, 0.18, 0.26), metallic=0.4, roughness=0.6)

    root = studio.empty("Warden")

    # Chassis. Broad and low, so all the vertical drama belongs to the mast.
    chassis = studio.sphere(
        "Body", radius=0.42, subdivisions=1,
        parent=root, location=(0.0, 0.0, 0.40), material=shell,
        scale=(1.2, 1.3, 0.5),
    )
    studio.bevel(chassis, width=0.018)

    # Skids rather than legs. This machine escorts a column at 4.0 - the
    # slowest non-Brute in the game - and should look like it is being carried
    # along rather than running.
    skid = studio.box(
        "Skid", size=(0.12, 0.86, 0.16),
        parent=root, location=(0.44, 0.0, 0.09), material=dark,
    )
    studio.mirror_x(skid, about=root)
    studio.bevel(skid, width=0.01)

    # Forward eye, low on the chassis, so the machine has a face at ground
    # level and the mast above it reads as equipment rather than as a head.
    studio.sphere(
        "Eye", radius=0.1, subdivisions=1,
        parent=chassis, location=(0.0, -0.44, 0.06), material=glow,
        scale=(1.5, 0.7, 0.7),
    )

    # Mast. Tapered, hexagonal-ish via the low segment count, planted in a
    # collar so the join reads as a bearing.
    collar = studio.cylinder(
        "Collar", radius_bottom=0.26, radius_top=0.22, height=0.12, segments=8,
        parent=root, location=(0.0, 0.0, 0.56), material=dark,
    )
    studio.bevel(collar, width=0.012)

    mast = studio.cylinder(
        "Mast", radius_bottom=0.15, radius_top=0.11,
        height=MAST_TOP - 0.66, segments=6,
        parent=root, location=(0.0, 0.0, 0.66), material=shell,
    )
    studio.bevel(mast, width=0.015)

    # Projector head at the top of the mast.
    head = studio.sphere(
        "ProjectorHead", radius=0.17, subdivisions=1,
        parent=root, location=(0.0, 0.0, HEAD_Z), material=dark,
        scale=(1.0, 1.0, 0.9),
    )
    studio.bevel(head, width=0.012)

    # Three emitter vanes around the head, at 120 degrees. Three rather than a
    # mirrored pair on purpose: a 3-fold arrangement has no flat side, so the
    # projector looks like it covers a radius from every viewing angle. The
    # Shielded Scout uses the same count for the same reason.
    for index, degrees in enumerate((90.0, 210.0, 330.0)):
        radians = math.radians(degrees)
        vane = studio.box(
            "Vane%d" % (index + 1), size=(0.07, 0.26, 0.3),
            parent=root,
            location=(math.cos(radians) * 0.3, math.sin(radians) * 0.3, HEAD_Z),
            material=glow,
        )
        vane.rotation_euler = (0.0, math.radians(-18.0), radians)
        studio.bevel(vane, width=0.008)

    # The field itself - the shell_node. Faceted, not smooth: it is a projected
    # lattice, not a soap bubble. Ships opaque; enemy_view.gd makes it
    # translucent, because transparency is a render decision.
    studio.sphere(
        "Field", radius=0.27, subdivisions=1,
        parent=root, location=(0.0, 0.0, HEAD_Z), material=field,
        scale=(1.0, 1.0, 0.95),
    )

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
