"""Shared modelling helpers for Bastion Line's procedural assets.

Design rules for everything in art/:

  * Geometry is built with bmesh, never bpy.ops. Operators depend on the UI
    context and behave differently headless; bmesh is context-free, so a model
    built here is identical in the editor and in `blender -b`.
  * Blender is Z-up, Godot is Y-up. The glTF exporter maps Blender +Z -> Godot
    +Y and Blender -Y -> Godot +Z. So a barrel that must point down Godot's +Z
    is modelled pointing along Blender -Y. FORWARD below is that axis.
  * Models carry no colour. `game/views/tower_view.gd` applies material_override
    from the TowerDef, so `data/towers/*.tres` stays the single source of truth
    for palette. Materials here exist only to make the Blender preview readable.
  * Node names are a contract with the view layer. Renaming "Base", "Turret" or
    "Barrel" silently breaks turret rotation and recoil.

Units are metres and match Godot 1:1. A grid cell is 2.0, so nothing should
exceed ~1.8 across or it will overhang its tile.
"""

import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# Godot's +Z (the direction a turret faces at rotation 0) in Blender space.
FORWARD = Vector((0.0, -1.0, 0.0))
UP = Vector((0.0, 0.0, 1.0))

# One grid cell. Keep footprints comfortably inside this.
CELL_SIZE = 2.0


# ---------------------------------------------------------------------------
# Scene setup
# ---------------------------------------------------------------------------

def reset_scene():
    """Empty the current file so a build never depends on what was open before.

    Deliberately NOT `bpy.ops.wm.read_factory_settings()`. That reloads
    preferences, which unregisters every addon - including the MCP bridge you
    may be driving this script through - and destroys the window context the
    glTF exporter needs. Purging datablocks achieves the same thing and leaves
    the running session intact.
    """
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials,
                  bpy.data.lights, bpy.data.cameras):
        for item in list(block):
            block.remove(item)


# The angle the game is actually played at. game/rts_camera.gd:44 sets
#     var pitch: float = deg_to_rad(-52.0)
# and _apply() builds the camera offset as
#     Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * distance
# so the camera sits sin(52) = 0.79 of its distance ABOVE the focus and
# cos(52) = 0.62 out from it: an elevation above the target of exactly 52
# degrees. The player can tilt between PITCH_MIN -80 and PITCH_MAX -12, but -52
# is the home value and what reset() returns to.
RTS_ELEVATION_DEG = 52.0


def preview_viewport(target=(0.0, 0.0, 0.85), distance=5.5,
                     azimuth_deg=38.0, elevation_deg=RTS_ELEVATION_DEG):
    """Point the user's 3D viewport at the model from a fixed angle.

    Worth doing rather than relying on wherever the viewport happened to be: a
    close level-on view flatters a silhouette that will actually be seen from
    above at distance, which is how the first Arc Cannon shipped as a squat
    plinth with an invisible turret.

    CORRECTED: this defaulted to 24 degrees and its docstring claimed that
    matched game/rts_camera.gd. It does not - the real home pitch is 52, more
    than double. Every silhouette judged through this helper before that fix
    was reviewed at an angle showing far more side profile and far less top
    than the player ever sees. If an older model looks wrong from up here, that
    is why, and it is worth a second look rather than a defence.

    azimuth 0 looks straight at the model's front (the face the barrels point
    out of); positive swings clockwise.
    """
    screen = getattr(bpy.context, "screen", None)
    if screen is None:
        return
    for area in screen.areas:
        if area.type != "VIEW_3D":
            continue
        region_3d = area.spaces.active.region_3d
        region_3d.view_perspective = "PERSP"
        region_3d.view_location = Vector(target)
        region_3d.view_distance = distance
        region_3d.view_rotation = Euler(
            (math.radians(90.0 - elevation_deg), 0.0, math.radians(azimuth_deg)),
            "XYZ",
        ).to_quaternion()


def preview_lighting():
    """A sun and a camera for previewing. Never exported - export_glb() runs
    before this is called, and filters lights and cameras out anyway.

    Both are hidden in the viewport: a camera gizmo sitting in front of the
    model is exactly the wrong thing to have in shot when you're judging a
    silhouette.
    """
    sun_data = bpy.data.lights.new("PreviewSun", type="SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("PreviewSun", sun_data)
    sun.rotation_euler = (math.radians(50), 0.0, math.radians(35))
    bpy.context.collection.objects.link(sun)
    sun.hide_viewport = True

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 55
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    cam.location = (3.2, -3.6, 2.6)
    cam.rotation_euler = (math.radians(64), 0.0, math.radians(41))
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.hide_viewport = True
    return sun, cam


# ---------------------------------------------------------------------------
# Mesh construction
# ---------------------------------------------------------------------------

def _finish(bm, name, parent=None, location=(0.0, 0.0, 0.0), material=None,
            smooth=False):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    if smooth:
        for polygon in mesh.polygons:
            polygon.use_smooth = True

    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    if material is not None:
        mesh.materials.append(material)
    bpy.context.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
        # Parenting in Blender keeps the world transform by default only if you
        # set parent_inverse; we want plain local offsets, so clear it.
        obj.matrix_parent_inverse = Matrix.Identity(4)
    return obj


def cylinder(name, radius_bottom, radius_top, height, segments=12,
             parent=None, location=(0.0, 0.0, 0.0), material=None,
             base_at_origin=True, smooth=False):
    """A cone/cylinder along +Z. `base_at_origin` puts the bottom face at the
    object origin, which is what you want for anything standing on the ground."""
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=height,
    )
    if base_at_origin:
        bmesh.ops.translate(bm, verts=bm.verts, vec=(0.0, 0.0, height * 0.5))
    return _finish(bm, name, parent, location, material, smooth)


def box(name, size, parent=None, location=(0.0, 0.0, 0.0), material=None):
    """Axis-aligned box centred on its origin. `size` is (x, y, z)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=Vector(size))
    return _finish(bm, name, parent, location, material)


def wedge(name, size, parent=None, location=(0.0, 0.0, 0.0), material=None,
          taper=0.5):
    """A box whose front face (toward Blender -Y, i.e. Godot +Z) is narrower.
    Cheap way to give a turret head a direction you can read at a glance."""
    x, y, z = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=(x, y, z))
    for vert in bm.verts:
        if vert.co.y < 0.0:
            vert.co.x *= taper
            vert.co.z *= taper
    return _finish(bm, name, parent, location, material)


def sphere(name, radius, subdivisions=2, parent=None, location=(0.0, 0.0, 0.0),
           material=None, scale=(1.0, 1.0, 1.0), smooth=False):
    """Low-poly icosphere. Flat-shaded by default - the faceting is the style,
    and it keeps enemies visually distinct from the towers' flat machined faces."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
    if scale != (1.0, 1.0, 1.0):
        bmesh.ops.scale(bm, verts=bm.verts, vec=Vector(scale))
    return _finish(bm, name, parent, location, material, smooth)


def prism(name, radius, height, segments=6, parent=None, location=(0.0, 0.0, 0.0),
          material=None, base_at_origin=True):
    """A flat-topped n-gon prism. Just cylinder() with a low segment count, but
    naming it prism makes the intent obvious at the call site."""
    return cylinder(name, radius, radius, height, segments=segments,
                    parent=parent, location=location, material=material,
                    base_at_origin=base_at_origin)


def empty(name, parent=None, location=(0.0, 0.0, 0.0)):
    """A transform-only node. Used for the Turret pivot, which the view layer
    rotates - the pivot must be a separate node from the geometry it carries."""
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.2
    obj.location = location
    bpy.context.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
        obj.matrix_parent_inverse = Matrix.Identity(4)
    return obj


def bevel(obj, width=0.02, segments=1):
    """A narrow bevel on every edge. On flat-shaded low-poly this is what stops
    silhouettes reading as untextured programmer boxes - it catches a highlight."""
    modifier = obj.modifiers.new(name="Bevel", type="BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(40)
    return modifier


def mirror_x(obj, about=None):
    """Mirror across X, for paired barrels, struts and vents.

    `about` is the object whose origin defines the mirror plane, defaulting to
    the parent. This matters: with no mirror_object Blender mirrors around the
    object's OWN origin, so an off-centre part gets mirrored onto itself and you
    get coincident geometry instead of a pair. That silently produced a
    single-barrelled Arc Cannon that looked almost right.
    """
    modifier = obj.modifiers.new(name="Mirror", type="MIRROR")
    modifier.use_axis = (True, False, False)
    mirror_object = about if about is not None else obj.parent
    if mirror_object is not None:
        modifier.mirror_object = mirror_object
    return modifier


# ---------------------------------------------------------------------------
# Materials (preview only - Godot overrides these from the .tres)
# ---------------------------------------------------------------------------

def material(name, color, metallic=0.2, roughness=0.55, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission > 0.0 and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*color, 1.0)
    return mat


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def project_root():
    """Repo root, derived from this file's location: art/lib/studio.py -> ../.."""
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(here, os.pardir, os.pardir))


def export_glb(root, relative_path):
    """Export `root` and its children to <repo>/<relative_path>.

    Only the selected hierarchy goes out, so preview lights and cameras never
    end up in the shipped asset.
    """
    out_path = os.path.join(project_root(), relative_path.replace("/", os.sep))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    # Deliberately NOT use_selection. Driving selection needs a live view layer,
    # which an addon-hosted context may not have. reset_scene() guarantees the
    # file holds only this model, and cameras/lights are filtered out below, so
    # exporting the whole scene is both simpler and more reliable.
    #
    # The exporter still reads bpy.context.active_object directly, so supply one.
    exported = [root] + list(root.children_recursive)
    override = {
        "active_object": root,
        "object": root,
        "selected_objects": exported,
        "selected_editable_objects": exported,
    }
    with bpy.context.temp_override(**override):
        bpy.ops.export_scene.gltf(
            filepath=out_path,
            export_format="GLB",
            use_selection=False,
            export_apply=True,        # bake modifiers, so bevels survive
            export_yup=True,          # Blender Z-up -> Godot Y-up
            export_cameras=False,
            export_lights=False,
        )
    print("exported %s" % out_path)
    return out_path
