# PENDING — asks awaiting the lead

A5 owns `art/**` and `data/models/**`, and now `data/icons/**` (see §1).
**No `.tres` file was opened or written this session.** Everything the art lane
needs from a resource, or from another agent's lane, is recorded here.

Last updated: 14 Aug 2026 — round 4, UI icons + map thumbnails.

---

## 1. Path convention for non-model art — DECIDED AND IN USE

`data/models/` is for `.glb`. Icons are not models, so:

```
data/icons/towers/<def_id>.png        12 tower icons, 256x256 RGBA
data/icons/towers/tint/<def_id>.png   12 tint masks  (see 2)
data/icons/maps/<map_id>.png           2 map thumbnails, 256x256 RGBA
```

Went with the lead's proposal unchanged; `data/icons/` sits beside
`data/models/` and is regenerated the same way. The `tint/` subfolder rather
than a `_tint` suffix keeps `data/icons/towers/` globbable — A4 can load the
whole directory without filtering out every other file.

Regenerate with:

```
blender -b --python art/render_icons.py     # 24 PNG, needs Blender
python3 art/render_thumbnails.py            # 2 PNG, stdlib only
```

`render_thumbnails.py` needs neither Blender nor Pillow — it draws from
`data/maps/*.layout.txt` and writes PNG with `zlib` and `struct`. That is
deliberate: it is the one part of the art pipeline that does not need a 3D
package, so it should not require one, and it can run in CI.

---

## 2. Runtime tinting — YES, and the masks are already rendered

**The recommendation is to tint at runtime.** The icons ship in a neutral
studio grey and will NOT match a tower on the board, because `body_color` and
`accent_color` live in `data/towers/*.tres` where a balance or design pass can
move them. A baked icon desyncs silently the first time someone edits a colour —
which is exactly how the Frost Mortar's hull colour drifted for a whole release
(§6). Tinting from the same fields the mesh uses cannot drift.

One `modulate` will not do it, because body and accent need different colours.
So every icon has a companion mask:

```
R channel = body coverage      (the parts tower_view.gd tints with body_color)
G channel = accent coverage    (the parts it tints with accent_color)
B channel = unused
alpha     = silhouette
```

Classification in `render_icons.py` mirrors `tower_view.gd`'s exactly — the
`LEGACY_*` exact names OR the `Body*` / `Accent*` prefixes — so what tints in
the icon is what tints on the board. Verified on `arc_cannon_t3a`: 57% of opaque
pixels body, 25% accent, 128px of overlap, all of it antialiased seams.

A canvas_item shader, whole thing:

```glsl
uniform sampler2D mask_tex;
uniform vec4 body_color : source_color;
uniform vec4 accent_color : source_color;
const vec3 NEUTRAL = vec3(1.0);

void fragment() {
    vec4 icon = texture(TEXTURE, UV);
    vec4 m = texture(mask_tex, UV);
    vec3 tint = body_color.rgb * m.r
              + accent_color.rgb * m.g
              + NEUTRAL * max(0.0, 1.0 - m.r - m.g);
    COLOR = vec4(icon.rgb * tint, icon.a);
}
```

Multiply works because the icons are deliberately near-greyscale
(`BODY_GREY` 0.70/0.72/0.76, `ACCENT_GREY` 0.90/0.88/0.82) — shading survives
and the hue comes entirely from the tint.

**If A4 would rather not ship a shader, the plain icons stand on their own** and
the masks cost nothing to ignore. They just won't match a recoloured tower.

---

## 3. Godot import settings — A4 will need these

Godot auto-imports PNGs and writes a `.import` next to each. Commit those with
the PNGs, the same way `data/models/*.glb.import` is committed. Four settings
matter at icon size:

| setting | value | why |
| --- | --- | --- |
| `detect_3d/compress_to` | **Disabled** | This is the trap. Godot silently rewrites a texture's import settings the first time it is used in a 3D material, switching it to VRAM compression. On a UI icon that is lossy for no benefit, and it happens without anyone touching the file. |
| `compress/mode` | **Lossless** | 26 small PNGs; there is nothing to save. |
| `mipmaps/generate` | **true** for the icons | A 256px icon drawn at 64px without mipmaps aliases hard on exactly the fine detail — rank bands, rotary tubes — that carries the tier read. |
| `process/fix_alpha_border` | **true** (default) | Transparent PNGs get dark fringes when filtered otherwise. |

**The masks are the exception: `compress/mode` MUST be Lossless and
`mipmaps/generate` should be false.** A mask is data, not a picture — lossy
compression bleeds R into G and mipmaps blur the boundary between body and
accent, both of which show up as the wrong colour on a seam.

---

## 4. Does the tier read at icon size? Measured, and there is a floor

Rendered, downsampled and judged small rather than at 512.

**At 64px: yes, all twelve.** Every family separates T1 / T2 / T3A / T3B.
- Arc: stub barrels → bulkier with twin drums → rotary cluster → long diagonal rail.
- Lance: thin barrel → rods and collimator rings → one fat emitter → three prongs.
- Mortar: plain drum → four tanks → broad with a big muzzle → tall banded barrel.

**At 32px: no. Only the tier-3 forks survive** — Hailstorm's round cluster and
Railshot's diagonal rail stay legible, everything else collapses toward its
family. **Recommend 64px as the minimum display size** in the build bar and
upgrade panel. Below that these want purpose-drawn flat glyphs, which is a
different and much larger job than rendering the meshes.

The Frost Mortar family is the weakest of the three at every size — it is the
squat family, its barrel elevates away from the camera, and its tier signals are
tank count and muzzle width rather than silhouette. Readable, but it has the
least margin, so if the UI ever renders below 64px that is the family that
breaks first.

Fill fractions, which are themselves a tier signal (one shared camera and one
orthographic scale for all twelve — see the script docstring):

```
arc_cannon 64%  t2 71%  t3a 76%  t3b 78%
plasma_lance 72%  t2 77%  t3a 88%  t3b 87%
frost_mortar 58%  t2 62%  t3a 58%  t3b 66%
```

---

## 5. A correction that affects everyone who has judged a silhouette

**`art/lib/studio.py`'s `preview_viewport` defaulted to 24 degrees of elevation
and its docstring claimed that matched `game/rts_camera.gd`. It does not.**

`rts_camera.gd:44` sets `pitch = deg_to_rad(-52.0)`, and `_apply()` builds the
offset as `Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))`,
so the camera sits `sin(52) = 0.79` of its distance above the focus: an
elevation of exactly **52 degrees**, more than double what the helper used.

Fixed, and exported as `studio.RTS_ELEVATION_DEG` so it stops being a magic
number. `preview_roster.py` passed the same wrong 24 explicitly and now uses the
constant.

**What this means for work already accepted:** every silhouette judged through
that helper — the four original enemies, the five new ones, the snow and desert
kits — was reviewed showing far more side profile and far less top than the
player ever sees. Nothing is known to be wrong, and the tier meshes are
unaffected (`preview_towers.py` sets its camera directly, and I checked those
at 24 and 30). But the Arc family's rank bands were moved down their plinth to
escape turret occlusion, and that was sized against 24 degrees; at 52 the turret
occludes *more*. **Worth a second look at the tier ladder from the corrected
angle before the upgrade panel ships.** I did not re-cut them this session
because the icon set was the deliverable.

---

## 6. Still open

1. **The prop table (was §1 last round).** Unchanged and now with the lead for
   A3. Sixteen built props are still scattered by nobody: eight snow, eight
   desert, and `crystal.glb`. `board.gd::_scatter_props()` hardcodes seven
   grassland paths and skips every in-bounds cell, so The Corridor grows pine
   forests in a desert canyon. Field names, weights for all three biomes, the
   blocked-cell pass and the y = 0.5 offset are in last round's PENDING and
   unchanged.
2. **Map thumbnail palettes are a mirror, not a read.** `render_thumbnails.py`
   hardcodes each map's ground/path/blocked colours because A5 does not open
   `.tres`. Same arrangement as `preview_map.py`'s placement constants: **if the
   two disagree the `.tres` is correct and the script is stale.** A map with no
   entry renders in neutral greys and warns. The durable fix is for the level
   select to generate these at runtime from `MapDef` plus the layout — a dozen
   lines of GDScript, never goes stale, and A4's call.
3. **No `fork` thumbnail.** `data/maps/` has `crossing` and `corridor` only.
   The script globs `*.layout.txt`, so the Fork's thumbnail appears the moment
   its layout lands — but its palette needs adding to `PALETTES`.
4. **Skiff cruise altitude** — still unspecified in `enemies.md`.
5. **`EnemyDef.body_color` is inert for modelled enemies.** `_setup_from_mesh`
   never tints; only the primitive fallback reads it. Every enemy model bakes
   its colour for this reason. `shielded_scout.tres` has already drifted from
   its model (`0.35,0.75,0.9` declared vs `0.2,0.42,0.55` baked).
6. **`voice.md` §3 vs the shipped palette.** It calls the Arc family "warm
   brass"; `arc_cannon.tres`'s `body_color` is blue and only the accent is
   brass. The tier colour proposals follow the `.tres`.
