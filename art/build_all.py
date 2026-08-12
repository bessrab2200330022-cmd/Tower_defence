"""Rebuild every model in art/ and export it.

    blender -b --python art/build_all.py

Or use scripts/build_art.ps1 / scripts/build_art.sh, which find Blender for you.

Each model script is run in a fresh namespace and must expose:
    build()      -> returns the root object
    OUTPUT_PATH  -> repo-relative .glb destination

Exit code is 1 if any model fails, so this can be a CI step. It is not one yet:
the .glb files are committed, so CI needs Godot but not Blender. That trade is
deliberate - adding Blender to CI would triple the job time to re-derive files
that are already in the repo and rarely change.
"""

import os
import sys
import traceback

ART_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ART_DIR, "lib"))

import studio  # noqa: E402


def discover():
    """Every art/<category>/<name>.py, sorted, so build order is stable."""
    found = []
    for category in sorted(os.listdir(ART_DIR)):
        category_dir = os.path.join(ART_DIR, category)
        if not os.path.isdir(category_dir) or category in ("lib", "__pycache__"):
            continue
        for file_name in sorted(os.listdir(category_dir)):
            if file_name.endswith(".py") and not file_name.startswith("_"):
                found.append(os.path.join(category_dir, file_name))
    return found


def build_one(script_path):
    """Run one model script. Two shapes are supported:

      OUTPUT_PATH + build()          - a single model
      VARIANTS = [{output, **kw}]    - several models from one parameterised
                                       build(**kw), e.g. three sizes of pine

    Variants exist because a prop kit is mostly the same shape at different
    scales, and three near-identical files is worse than one file with a table.
    """
    namespace = {"__name__": "__build_all__", "__file__": script_path}
    with open(script_path, "r", encoding="utf-8") as handle:
        exec(compile(handle.read(), script_path, "exec"), namespace)

    if "build" not in namespace:
        raise RuntimeError("no build() function")

    variants = namespace.get("VARIANTS")
    if variants:
        for variant in variants:
            params = dict(variant)
            output = params.pop("output", "")
            if not output:
                raise RuntimeError("variant missing 'output'")
            root = namespace["build"](**params)
            studio.export_glb(root, output)
        return

    if not namespace.get("OUTPUT_PATH"):
        raise RuntimeError("no OUTPUT_PATH and no VARIANTS")
    root = namespace["build"]()
    studio.export_glb(root, namespace["OUTPUT_PATH"])


def main():
    scripts = discover()
    if not scripts:
        print("no model scripts found under %s" % ART_DIR)
        return 0

    failures = []
    for script_path in scripts:
        label = os.path.relpath(script_path, ART_DIR).replace(os.sep, "/")
        try:
            build_one(script_path)
            print("  [ ok ] %s" % label)
        except Exception:
            failures.append(label)
            print("  [FAIL] %s\n%s" % (label, traceback.format_exc()))

    print("")
    if failures:
        print("FAIL  %d of %d models: %s" % (len(failures), len(scripts), ", ".join(failures)))
        return 1
    print("PASS  %d models built" % len(scripts))
    return 0


if __name__ == "__main__":
    status = main()
    # Blender ignores sys.exit() in --python unless we force it.
    import bpy
    bpy.ops.wm.quit_blender() if status == 0 else sys.exit(status)
