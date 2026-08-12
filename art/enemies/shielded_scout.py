"""Shielded Scout - energy shielding shrugs off kinetic fire.

This is the enemy that punishes a player who built nothing but Arc Cannons, so
the counter has to be legible before it is in range. The shield bubble is the
whole design: a visible layer wrapped around a small body, in the same blue as
the Plasma Lance's emitter. Colour-matching the counter to the threat is the
cheapest teaching tool a tower defence has.

Note this leans on colour, which `docs/BACKLOG.md` item 12 flags as an
accessibility problem. The bubble's distinct shape is the mitigation - it is
the only enemy with a concentric outer layer, so it is identifiable without
relying on hue.

Output: data/models/enemies/shielded_scout.glb
"""

import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/enemies/shielded_scout.glb"

RADIUS = 0.45
HEIGHT = 1.1


def build():
    studio.reset_scene()

    core = studio.material("Core", (0.2, 0.42, 0.55), metallic=0.4, roughness=0.4)
    field = studio.material("Field", (0.4, 0.82, 0.98), emission=0.9, roughness=0.25)
    glow = studio.material("Glow", (0.8, 0.98, 1.0), emission=1.8, roughness=0.2)
    dark = studio.material("Dark", (0.12, 0.18, 0.24), metallic=0.35, roughness=0.6)

    root = studio.empty("ShieldedScout")

    centre_z = HEIGHT * 0.52

    # Small inner body. Deliberately slighter than the Walker's - the bulk you
    # see is the field, not the machine, which is why killing the field kills it.
    body = studio.sphere(
        "Body", radius=RADIUS * 0.6, subdivisions=1,
        parent=root, location=(0.0, 0.0, centre_z), material=core,
        scale=(0.9, 1.2, 0.95),
    )
    studio.bevel(body, width=0.015)

    studio.sphere(
        "Eye", radius=0.09, subdivisions=1,
        parent=body, location=(0.0, -0.3, 0.04), material=glow,
    )

    # Three emitter nodes on the hull - the things generating the bubble. They
    # give the shield a mechanical cause rather than looking like a render bug.
    for index, offset in enumerate([(0.3, 0.16), (-0.3, 0.16), (0.0, -0.34)]):
        studio.box(
            "Emitter%d" % (index + 1), size=(0.12, 0.12, 0.2),
            parent=body, location=(offset[0], offset[1], 0.22), material=glow,
        )

    # The field itself. A low-subdivision sphere, so it faceted rather than
    # smooth - it should look like a constructed lattice, not a soap bubble.
    # Kept opaque here; game/views/enemy_view.gd makes it translucent, because
    # transparency settings belong with the renderer, not the mesh.
    shield = studio.sphere(
        "Shield", radius=RADIUS * 1.16, subdivisions=1,
        parent=root, location=(0.0, 0.0, centre_z), material=field,
        scale=(1.0, 1.08, 1.0),
    )

    # Skids, so it does not look like it is simply floating for no reason.
    skid = studio.box(
        "Skid", size=(0.1, 0.5, 0.1),
        parent=root, location=(0.26, 0.0, 0.06), material=dark,
    )
    studio.mirror_x(skid, about=root)
    studio.bevel(skid, width=0.01)

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
