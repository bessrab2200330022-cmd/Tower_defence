"""Render the tower build-bar / upgrade-panel icons.

    blender -b --python art/render_icons.py

Output:
    data/icons/towers/<def_id>.png        the icon, RGBA, transparent ground
    data/icons/towers/tint/<def_id>.png   tint mask, R = body, G = accent

THE SCRIPT IS THE ICON SET
--------------------------
Same principle as the models: a PNG someone rendered by hand once is a PNG that
goes stale the first time a mesh changes, and nobody notices until the upgrade
panel is showing a Hailstorm that no longer exists. This regenerates all twelve
from the current .glb files in one command, so "rebuild the art" stays one step.

WHY EVERY ICON SHARES ONE CAMERA AND ONE ORTHOGRAPHIC SCALE
-----------------------------------------------------------
Framing each tower to fill its own square would be the obvious thing and it
would destroy the entire point. These icons sit in an upgrade panel where the
player is choosing between a tower and its successor, so the ONLY question the
image has to answer is "how is this one different from that one". Auto-framing
normalises away the single clearest difference - size - and leaves twelve
pictures of a turret.

So: one camera, one ORTHO_SCALE, one target, one light rig, for all twelve. A
Prime Focus at 2.62 units fills noticeably more of its square than a base Arc
Cannon at 1.59, and that is a tier signal the player gets for free before they
have parsed any detail at all.

The cost is that no icon is perfectly framed. That is the right trade.

ANGLE
-----
ELEVATION_DEG is 42, between the 52 the game is actually played at (see
studio.RTS_ELEVATION_DEG) and the ~30 that flatters a turret in isolation.
Leaning toward the game angle matters because the icon's first job is
recognition: the player has to match this picture to a thing on the board. But
a full 52 foreshortens the Railshot's rail - the one silhouette that IS its
length - so this backs off ten degrees to keep some profile.

TINTING
-------
The models carry no colour by contract; game/views/tower_view.gd applies
TowerDef.body_color and accent_color at runtime. These icons therefore render in
a neutral studio palette and will NOT match a tinted tower on the board.

A single modulate cannot fix that, because body and accent need different
colours. So each icon also gets a mask: R = body coverage, G = accent coverage,
alpha = silhouette. A4 can then tint in a small shader:

    tint = body_color * mask.r + accent_color * mask.g + NEUTRAL * (1 - mask.r - mask.g)
    final.rgb = icon.rgb * tint

which preserves the shading because the icon is near-greyscale. If A4 would
rather not, the plain icon stands on its own and the masks cost nothing to
ignore. See art/PENDING.md.

Part classification below mirrors tower_view.gd exactly - legacy exact names OR
the Body*/Accent* prefixes - so what tints in the icon is what tints in game.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "lib"))

import studio  # noqa: E402

TOWERS = [
    "arc_cannon", "arc_cannon_t2", "arc_cannon_t3a", "arc_cannon_t3b",
    "plasma_lance", "plasma_lance_t2", "plasma_lance_t3a", "plasma_lance_t3b",
    "frost_mortar", "frost_mortar_t2", "frost_mortar_t3a", "frost_mortar_t3b",
]

SIZE = 256                 # power of two; UI scales it down, see PENDING.md
AZIMUTH_DEG = 35.0
ELEVATION_DEG = 42.0
# MEASURED, not estimated. The analytic worst case (arc_cannon_t3b's 3.39-deep
# rail projected diagonally) over-predicts badly, because the bounding box of a
# diagonal object is not the sum of its projected axes. Rendering the set once
# at 3.95 and measuring the alpha bounding boxes gave a real worst case of
# plasma_lance_t3a filling 0.715 of the frame - so every icon was floating in
# 30% wasted margin, which at 64px is the difference between a readable turret
# and a smudge.
#
# 3.20 puts the largest at ~88% and leaves the base Frost Mortar near 58%. That
# spread IS the tier signal - see the docstring - so it is deliberate, not slack
# to be tuned away. Re-measure if a mesh ever grows past the Lance.
ORTHO_SCALE = 3.20
TARGET = (0.0, 0.0, 1.18)

ICON_DIR = "data/icons/towers"
MASK_DIR = "data/icons/towers/tint"

# Mirrors game/views/tower_view.gd. LEGACY_* are the exact names it matched
# before A4 added prefix matching; both are still live there, so both are here.
LEGACY_BODY = ("Base", "Plinth", "TurretHead")
LEGACY_ACCENT = ("AmmoDrum", "Sight", "Muzzle")

# Neutral studio palette. Deliberately near-greyscale so that multiplying by a
# tint (see the docstring) lands on the tint's own hue rather than halfway to
# whatever the icon was already.
BODY_GREY = (0.70, 0.72, 0.76)
ACCENT_GREY = (0.90, 0.88, 0.82)
DARK_GREY = (0.24, 0.25, 0.28)


def classify(node_name):
    stem = node_name.split(".")[0]
    if stem in LEGACY_BODY or stem.startswith("Body"):
        return "body"
    if stem in LEGACY_ACCENT or stem.startswith("Accent"):
        return "accent"
    return "other"


def flat(name, colour, emission=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        if emission:
            # Base black + emission = the exact value out, with no shading and
            # no dependence on the light rig. The mask must be readable as data,
            # not as a picture.
            bsdf.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = (*colour, 1.0)
                bsdf.inputs["Emission Strength"].default_value = 1.0
        else:
            bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
            bsdf.inputs["Metallic"].default_value = 0.15
            bsdf.inputs["Roughness"].default_value = 0.5
    mat.diffuse_color = (*colour, 1.0)
    return mat


def import_tower(def_id):
    path = os.path.join(studio.project_root(), "data", "models", "towers",
                        "%s.glb" % def_id)
    if not os.path.exists(path):
        print("missing", path)
        return None
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    roots = [o for o in bpy.data.objects if o not in before and o.parent is None]
    return roots[0] if roots else None


def paint(root, palette):
    """Replace every material with one of three, chosen by node name."""
    for child in [root] + list(root.children_recursive):
        if child.type != "MESH":
            continue
        child.data.materials.clear()
        child.data.materials.append(palette[classify(child.name)])


def setup_camera():
    cam_data = bpy.data.cameras.new("IconCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO_SCALE
    cam_data.clip_start = 0.1
    cam_data.clip_end = 100.0
    cam = bpy.data.objects.new("IconCam", cam_data)
    bpy.context.collection.objects.link(cam)

    azimuth = math.radians(AZIMUTH_DEG)
    elevation = math.radians(ELEVATION_DEG)
    direction = Vector((math.sin(azimuth) * math.cos(elevation),
                        math.cos(azimuth) * math.cos(elevation),
                        -math.sin(elevation)))
    cam.location = Vector(TARGET) - direction * 20.0
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def setup_lights():
    """Key, fill and rim. Fixed for every icon - a set whose lighting drifts
    reads as sloppy even when each image is fine on its own."""
    made = []
    for name, energy, rotation in (
            ("Key", 4.2, (math.radians(52), 0.0, math.radians(34))),
            ("Fill", 1.5, (math.radians(66), 0.0, math.radians(-118))),
            ("Rim", 2.6, (math.radians(104), 0.0, math.radians(196))),
    ):
        data = bpy.data.lights.new(name, type="SUN")
        data.energy = energy
        data.angle = math.radians(12.0)
        obj = bpy.data.objects.new(name, data)
        obj.rotation_euler = rotation
        bpy.context.collection.objects.link(obj)
        made.append(obj)
    return made


def configure_render():
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except Exception:
            continue
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    # Standard, not Filmic/AgX. A tone-mapped mask is not a mask - the R and G
    # channels have to come out as the exact values they went in as.
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
    except Exception:
        pass
    return scene


def set_world(colour):
    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("IconWorld")
        bpy.context.scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background is not None:
        background.inputs["Color"].default_value = (*colour, 1.0)
        background.inputs["Strength"].default_value = 1.0


def render_to(relative_path):
    scene = bpy.context.scene
    out = os.path.join(studio.project_root(), relative_path.replace("/", os.sep))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    return out


def render_one(def_id):
    # --- the icon --------------------------------------------------------
    studio.reset_scene()
    scene = configure_render()
    set_world((0.10, 0.11, 0.13))          # a little ambient, not pitch black
    root = import_tower(def_id)
    if root is None:
        return 0
    paint(root, {
        "body": flat("IconBody", BODY_GREY),
        "accent": flat("IconAccent", ACCENT_GREY),
        "other": flat("IconDark", DARK_GREY),
    })
    setup_camera()
    setup_lights()
    render_to("%s/%s.png" % (ICON_DIR, def_id))

    # --- the tint mask ---------------------------------------------------
    studio.reset_scene()
    configure_render()
    set_world((0.0, 0.0, 0.0))             # no ambient: the mask is data
    root = import_tower(def_id)
    if root is None:
        return 1
    paint(root, {
        "body": flat("MaskBody", (1.0, 0.0, 0.0), emission=True),
        "accent": flat("MaskAccent", (0.0, 1.0, 0.0), emission=True),
        "other": flat("MaskOther", (0.0, 0.0, 0.0), emission=True),
    })
    setup_camera()                          # identical camera, or the mask
    render_to("%s/%s.png" % (MASK_DIR, def_id))   # would not register
    return 2


def main():
    written = 0
    for def_id in TOWERS:
        written += render_one(def_id)
        print("  [ ok ] %s" % def_id)
    print("\n%d PNG written for %d towers -> %s" % (written, len(TOWERS), ICON_DIR))
    return written


if __name__ == "__main__" or __name__ in ("__reload__", "__mcp__"):
    main()
