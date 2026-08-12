"""Fission Crawler - the splitter. 2,200 HP, speed 4.2, Medium armour.

docs/design/enemies.md: SPLIT_ON_DEATH spawns 2 x Fission Spawn at the parent's
exact path progress. And the readability note that decides this entire model:

    "segmented body with a visible seam; the death split should read as the
     body COMING APART INTO THE TWO CHILDREN, not two spawns popping in."

You cannot satisfy that sentence with a monolithic body and a decal. So the
Crawler is not a body with a seam drawn on it - it is literally two instances
of build_segment() at y = -0.40 and +0.40, joined by a collar that is the only
thing between them. art/enemies/fission_spawn.py imports that same function.
The child model IS the parent's half, because they are the same code.

That buys three things:

  1. The split reads correctly for free. Whatever A4 does with the death event -
     even the cheapest version, two children fading in at the parent's
     position - the shapes already match what was standing there.
  2. "Kill it early" becomes visible policy. A machine that is visibly two
     machines lightly bolted together is a machine you expect to get two more
     of. The counter-play (enemies.md 3: kill early, splash at the death zone)
     is legible from the model.
  3. Editing the segment edits both. A proportion change cannot desync the
     parent from its children, which is exactly the drift a hand-copied second
     model would have produced by the third revision.

The seam glows because it is the failure point, and low and long is the read:
at 1.0 tall it is the lowest ground enemy above the Courser, which suits a
machine that is mostly chassis and no crew.

Output: data/models/enemies/fission_crawler.glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), os.pardir, "lib"))

import studio  # noqa: E402

OUTPUT_PATH = "data/models/enemies/fission_crawler.glb"

RADIUS = 0.55
HEIGHT = 1.0

SEGMENT_OFFSET = 0.40


def materials():
    """Shared by the Crawler and by fission_spawn.py, for the same reason
    build_segment is: the child must not drift from the parent."""
    return {
        # Medium armour is the red family (Walker 0.8/0.35/0.4). Pushed toward
        # violet so a Crawler is not mistaken for the Walkers it shares wave 9
        # with - and so the unstable green core has something to fight.
        "shell": studio.material("Shell", (0.72, 0.38, 0.48),
                                 metallic=0.32, roughness=0.5),
        # Green-yellow, and the only enemy glow that is not warm or cyan.
        # Fission is meant to look like a fault, not like running lights.
        "glow": studio.material("Glow", (0.75, 1.0, 0.4),
                                emission=1.7, roughness=0.25),
        "dark": studio.material("Dark", (0.18, 0.12, 0.17),
                                metallic=0.35, roughness=0.6),
    }


def build_segment(name, parent, offset_y, mats, scale=1.0, seam_face=0.0):
    """One half of a Crawler, which is also one whole Fission Spawn.

    `seam_face` is which way the torn end points: -1 or +1 along Y, or 0 for a
    segment that is still attached to its twin and therefore has no torn end
    to show. The Spawn passes a non-zero value so the child carries the scar of
    where it came from - the cheapest possible "these two used to be one".
    """
    pod_z = 0.50 * scale

    # The pod takes the bare prefix, so the leading segment's is named exactly
    # "Body". Verified against game/views/enemy_view.gd: _setup_from_mesh sets
    # `body = model` - the imported ROOT - so the chill squash and heading
    # rotation work regardless of what the children are called, and this model
    # rendered correctly without it. Named anyway: the enemy contract asks for
    # a Body node, it costs one line, and the symmetry with BodyRear survives.
    pod = studio.sphere(
        name, radius=0.34 * scale, subdivisions=1,
        parent=parent, location=(0.0, offset_y, pod_z), material=mats["shell"],
        scale=(1.0, 0.82, 0.95),
    )
    studio.bevel(pod, width=0.016 * scale)

    # Two pairs of crawling legs per segment, angled out and back. Small and
    # many: the machine should look like it scuttles, which is also why it is
    # the only enemy with more than two legs a side.
    for index, along in enumerate((-0.2, 0.2)):
        leg = studio.box(
            "%sLeg%d" % (name, index + 1), size=(0.09, 0.1, 0.44),
            parent=parent,
            location=(0.34 * scale, offset_y + along * scale, 0.22 * scale),
            material=mats["dark"],
        )
        leg.rotation_euler = (0.0, math.radians(21.0), 0.0)
        studio.mirror_x(leg, about=parent)
        studio.bevel(leg, width=0.008)

    # Dorsal plate. Sets the crown, and gives the top-down view the segment
    # count as a plain visual fact - two plates, two children.
    plate = studio.box(
        "%sPlate" % name, size=(0.42 * scale, 0.5 * scale, 0.14 * scale),
        parent=parent, location=(0.0, offset_y, 0.9 * scale), material=mats["shell"],
    )
    studio.bevel(plate, width=0.012)

    # Core, visible through the shoulder of the pod.
    studio.sphere(
        "%sCore" % name, radius=0.13 * scale, subdivisions=1,
        parent=parent, location=(0.0, offset_y, 0.78 * scale), material=mats["glow"],
        scale=(1.2, 1.0, 0.6),
    )

    if seam_face:
        # The torn face, for a segment that has already come apart.
        studio.sphere(
            "%sSeam" % name, radius=0.2 * scale, subdivisions=1,
            parent=parent,
            location=(0.0, offset_y + seam_face * 0.26 * scale, pod_z),
            material=mats["glow"],
            scale=(0.9, 0.35, 0.85),
        )

    return pod


def build():
    studio.reset_scene()
    mats = materials()

    root = studio.empty("FissionCrawler")

    # Two segments, prefixed Body/BodyRear -> BodyPod, BodyRearPod and so on.
    # Nothing in the view layer looks these up by name: enemy_view.gd scales the
    # instantiated ROOT for the chill squash, not a child called Body. (drone.py's
    # docstring says otherwise and is out of date - only the primitive fallback
    # ever creates a node literally named Body.) The prefix is for humans.
    build_segment("Body", root, -SEGMENT_OFFSET, mats)
    build_segment("BodyRear", root, SEGMENT_OFFSET, mats)

    # The seam. A narrow dark collar with the fault glowing through it - the
    # only thing holding the machine together, and the thing that fails.
    collar = studio.cylinder(
        "Seam", radius_bottom=0.26, radius_top=0.26, height=0.34, segments=8,
        parent=root, location=(0.0, -0.17, 0.5), material=mats["dark"],
        base_at_origin=False,
    )
    collar.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    studio.bevel(collar, width=0.012)

    studio.sphere(
        "SeamGlow", radius=0.2, subdivisions=1,
        parent=root, location=(0.0, 0.0, 0.5), material=mats["glow"],
        scale=(1.05, 0.42, 1.0),
    )

    # Head sensors on the leading segment only, so the machine has a direction.
    sensor = studio.sphere(
        "Sensor", radius=0.08, subdivisions=1,
        parent=root, location=(0.13, -0.74, 0.54), material=mats["glow"],
        scale=(1.0, 0.8, 0.9),
    )
    studio.mirror_x(sensor, about=root)

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
