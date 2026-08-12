"""Line the whole enemy roster up side by side, at the RTS camera angle.

preview_map.py answers "does this look right on the board". This answers the
other question, and it is the one that actually decides an enemy model: can you
tell these nine machines apart, in one glance, from where the player sits?

That is not a question you can answer one model at a time. Silhouette is
comparative - the Brute only reads as heavy next to something that isn't, the
Courser only reads as low next to the Drone. Judging a new enemy alone in a
scene is how you ship a Brute shorter than a Walker (art/README.md), and it is
how the Courser first came out taller than the Drone in this very session.

Ordered by measured height, left to right, standing on a common ground plane so
the height ladder is a thing you can see rather than a table you have to trust.

Run:  blender -b --python art/preview_roster.py   (or Alt+P from the Text editor)
"""

import os
import sys

import bpy

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "lib"))

import studio  # noqa: E402

# Ordered by measured crown height. Keep this list in that order - reading the
# ladder left to right is the whole point of the tool.
ROSTER = [
    "courser", "drone", "fission_crawler", "skiff", "shielded_scout",
    "walker", "mender", "warden", "brute",
]

SPACING = 1.9


def _import(rel_path):
    path = os.path.join(studio.project_root(), rel_path.replace("/", os.sep))
    if not os.path.exists(path):
        print("missing", rel_path)
        return None
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    roots = [o for o in bpy.data.objects if o not in before and o.parent is None]
    return roots[0] if roots else None


def build():
    studio.reset_scene()

    # Ground plane, so nothing floats ambiguously and the Skiff's air gap - the
    # only intentional one in the roster - is obviously intentional.
    ground = studio.box(
        "Ground", size=(len(ROSTER) * SPACING + 3.0, 6.0, 0.1),
        location=((len(ROSTER) - 1) * SPACING * 0.5, 0.0, -0.05),
        material=studio.material("Ground", (0.28, 0.46, 0.26), roughness=0.95),
    )

    placed = 0
    for index, enemy_id in enumerate(ROSTER):
        model = _import("data/models/enemies/%s.glb" % enemy_id)
        if model is None:
            continue
        model.location = (index * SPACING, 0.0, 0.0)
        placed += 1

    studio.preview_lighting()
    studio.preview_viewport(
        target=((len(ROSTER) - 1) * SPACING * 0.5, 0.0, 0.6),
        distance=len(ROSTER) * SPACING * 1.15,
        azimuth_deg=0.0,
        elevation_deg=24.0,
    )
    print("roster preview: %d of %d models" % (placed, len(ROSTER)))
    return ground


if __name__ == "__main__" or __name__ == "__reload__":
    build()
