"""Fission Spawn - half a crawler, twice the hurry. 450 HP, speed 6.5, Light.

voice.md 4. enemies.md 2: never appears in a spawn group, exists only as
SPLIT_ON_DEATH offspring - two of them, at the parent's exact path position, in
the same tick its death is processed.

THIS MODEL IS NOT A MODEL, IT IS A CALL
---------------------------------------
    build_segment("Body", root, 0.0, mats, scale=SCALE, seam_face=1.0)

That single line is the entire asset, and it is the whole design. enemies.md 6
asks that "the death split should read as the body COMING APART INTO THE TWO
CHILDREN, not two spawns popping in", and the only way to guarantee that is for
the child to be the same geometry as the parent's half rather than a small
model that resembles one.

fission_crawler.py was factored into build_segment() for exactly this, one
round in advance. So:

  * The Spawn cannot drift from the Crawler. There is no second copy of the
    pod, the legs, the plate or the core to keep in sync - change the segment
    and both change, in the same commit, or neither does.
  * The materials come from fission_crawler.materials() for the same reason.
    A hand-matched palette is a palette that diverges on the third revision;
    shielded_scout.tres has already done exactly that (art/PENDING.md 5).
  * The player's read is free. Whatever A4 does with the death event - even the
    cheapest version, two children fading in at the parent's position - the
    shapes already match what was standing there a frame earlier.

WHAT IS DIFFERENT, AND WHY EACH DIFFERENCE EARNS ITS PLACE
----------------------------------------------------------
  * SCALE 0.75. It has to be a FRAGMENT, not a small crawler. At three quarters
    the parent's segment it reads as a piece; much above that and two of them
    look like a Crawler that failed to fuse.
  * seam_face=1.0 - the torn end, showing the exposed core where the seam gave
    way. It points BACKWARD, so the intact sensor end leads. This is the one
    thing the Crawler's own segments never show: attached, they have no torn
    face, because they are still joined to each other.
  * Sensors. The Crawler carries them on its leading segment only; a Spawn is
    now a whole machine and needs a front of its own.

Speed 6.5 against the parent's 4.2 is not modelled. It has one segment's legs
where the parent had two sets, which is the honest read - and enemies.md gives
the Courser the job of making speed visible standing still, so this does not
need to compete.

Output: data/models/enemies/fission_spawn.glb
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, os.pardir, "lib"))
sys.path.insert(0, _HERE)

import studio  # noqa: E402

# Dropped before import so a rebuild inside a running Blender picks up edits to
# fission_crawler.py without a restart - the same reason art/reload.py drops
# `studio`. Without this the parent could be edited and the child would quietly
# keep building from the stale module, which is precisely the drift this whole
# arrangement exists to prevent.
sys.modules.pop("fission_crawler", None)
import fission_crawler  # noqa: E402

OUTPUT_PATH = "data/models/enemies/fission_spawn.glb"

# Three quarters of one parent segment. See the docstring.
SCALE = 0.75

RADIUS = 0.39
HEIGHT = 0.73


def build():
    studio.reset_scene()
    mats = fission_crawler.materials()

    root = studio.empty("FissionSpawn")

    # Named "Body" so the leading pod carries the enemy contract's node name,
    # matching the Crawler's own leading segment.
    fission_crawler.build_segment(
        "Body", root, 0.0, mats, scale=SCALE, seam_face=1.0,
    )

    # Torn teeth along the rear edge of the dorsal plate.
    #
    # build_segment's seam_face already puts an exposed core on the back of the
    # pod, but that faces AWAY from a camera looking down the lane - checked in
    # a render, where it was completely hidden. The scar has to be visible from
    # above or it is not visible at all, so the break is also carried on the top
    # surface, where the plate is torn through. Spawn-only: the Crawler's own
    # segments are still joined and have nothing to show.
    for index, across in enumerate((-0.09, 0.0, 0.10)):
        tooth = studio.box(
            "BodyTear%d" % (index + 1),
            size=(0.075 * SCALE, 0.08 * SCALE, 0.1 * SCALE),
            parent=root,
            location=(across, 0.2 * SCALE, (0.9 - 0.02 * (index % 2)) * SCALE),
            material=mats["glow"],
        )
        tooth.rotation_euler = (0.0, 0.0, 0.4 * (index - 1))

    # Its own eyes. The parent wears these on the front segment only, so a
    # Spawn built from a bare segment would be faceless.
    sensor = studio.sphere(
        "Sensor", radius=0.075 * SCALE / 0.75, subdivisions=1,
        parent=root, location=(0.11, -0.42 * SCALE, 0.54 * SCALE),
        material=mats["glow"], scale=(1.0, 0.8, 0.9),
    )
    studio.mirror_x(sensor, about=root)

    return root


if __name__ == "__main__":
    model = build()
    studio.export_glb(model, OUTPUT_PATH)
    studio.preview_lighting()
