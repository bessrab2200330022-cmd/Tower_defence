"""Rebuild one model in the running Blender session.

Open this file in Blender's Scripting workspace and press Alt+P to rebuild.
Point MODEL at whichever asset you're working on.

Why this exists: the .py file is the asset, not the .blend. Nothing in the
Blender session is worth keeping, so a rebuild can safely wipe and recreate
everything. That is what makes "edit script, press Alt+P, look" a tight loop.

Set EXPORT = False while you're iterating on shape - it skips writing the .glb,
so you aren't churning a binary in git on every tweak.
"""

import os
import sys

import bpy

# --- what to build ---------------------------------------------------------
MODEL = "towers/arc_cannon.py"
EXPORT = True
FRAME_VIEW = True   # zoom the viewport to fit after building
# ---------------------------------------------------------------------------


def _art_dir():
    """This file's folder. Works whether run via Alt+P, --python, or exec()."""
    try:
        return os.path.dirname(os.path.abspath(__file__))
    except NameError:
        pass
    text = bpy.context.space_data.text if hasattr(bpy.context, "space_data") else None
    if text is not None and text.filepath:
        return os.path.dirname(bpy.path.abspath(text.filepath))
    raise RuntimeError("Cannot locate art/. Save this script to disk first.")


def _frame_all():
    """View > Frame All, without needing the mouse to be over the viewport."""
    for area in bpy.context.screen.areas:
        if area.type != "VIEW_3D":
            continue
        region = next((r for r in area.regions if r.type == "WINDOW"), None)
        if region is None:
            continue
        with bpy.context.temp_override(area=area, region=region):
            bpy.ops.view3d.view_all(center=False)
        return


def main():
    art_dir = _art_dir()
    lib_dir = os.path.join(art_dir, "lib")
    if lib_dir not in sys.path:
        sys.path.insert(0, lib_dir)

    # Drop cached modules so edits to studio.py take effect without restarting
    # Blender. This is the single most annoying thing about Blender scripting
    # and the single easiest thing to fix.
    for name in ("studio",):
        sys.modules.pop(name, None)

    import studio  # noqa: E402

    script_path = os.path.join(art_dir, MODEL.replace("/", os.sep))
    if not os.path.exists(script_path):
        raise FileNotFoundError(script_path)

    namespace = {"__name__": "__reload__", "__file__": script_path}
    with open(script_path, "r", encoding="utf-8") as handle:
        exec(compile(handle.read(), script_path, "exec"), namespace)

    root = namespace["build"]()

    # Export first: the shipped .glb should contain the model and nothing else.
    if EXPORT:
        out = namespace.get("OUTPUT_PATH")
        if out:
            studio.export_glb(root, out)
        else:
            print("no OUTPUT_PATH in %s, skipping export" % MODEL)

    studio.preview_lighting()

    if FRAME_VIEW:
        try:
            _frame_all()
        except Exception as error:      # viewport framing is a nicety, never fatal
            print("could not frame view: %s" % error)

    print("rebuilt %s" % MODEL)


main()
