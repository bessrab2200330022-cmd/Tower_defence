extends Node3D
## Sky, sun, shadows, ambient occlusion, reflections and bloom.
##
## Pulled out of level.gd because rendering settings are the thing most likely
## to be tweaked repeatedly and least likely to be understood six weeks later.
## Everything here is one node's worth of setup with the reasoning attached.
##
## Requires the Forward+ renderer (see project.godot). The Compatibility
## renderer silently drops SSAO, SSIL and screen-space reflections - it will
## still run, it will just look flat, which is a confusing way to fail.
##
## Nothing here touches the simulation. Lighting is pure presentation, so a
## change in this file must never alter `Simulation.snapshot_hash()`.

enum Quality {
	LOW,     ## Integrated graphics / Steam Deck. Sky, sun and shadows only.
	MEDIUM,  ## Adds SSAO and soft shadows.
	HIGH,    ## Adds SDFGI, SSIL and screen-space reflections.
}

## Change this to see the cost/benefit. If the frame rate is a problem, drop to
## MEDIUM first: that removes SDFGI, which is by a wide margin the most
## expensive thing here, along with SSIL and SSR.
const DEFAULT_QUALITY: Quality = Quality.HIGH

## Sun direction. Chosen so the low afternoon angle throws shadows across the
## board rather than straight down - shadows are what give the terrain slabs
## their thickness, and a midday sun would flatten them back out.
const SUN_ROTATION := Vector3(-46.0, -132.0, 0.0)

## A soft blue bounce from the opposite side. Without it the shadowed faces of
## every slab go near-black and the low-poly forms lose their edges, which is
## the exact opposite of what this art direction needs.
const FILL_ROTATION := Vector3(-24.0, 48.0, 0.0)

var environment: Environment
var sun: DirectionalLight3D
var fill: DirectionalLight3D

var _quality: Quality = DEFAULT_QUALITY


func build(quality: Quality = DEFAULT_QUALITY) -> void:
	_quality = quality
	_build_environment()
	_build_sun()
	_build_fill()


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	environment = Environment.new()

	_apply_sky()
	_apply_tonemap()
	_apply_glow()
	_apply_ambient_occlusion()
	_apply_global_illumination()
	_apply_reflections()
	_apply_fog()

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


## A real sky, not a flat colour. This is what "reflections" mostly means for
## stylised art: every metal surface picks up the sky gradient, so a tower's
## curved plating reads as metal instead of as grey paint. A flat background
## colour cannot do that at any quality level.
func _apply_sky() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.24, 0.47, 0.84)
	sky_material.sky_horizon_color = Color(0.74, 0.87, 0.96)
	# The board is a floating island, so there is no ground - the camera can and
	# will look below the horizon. Keeping the lower hemisphere a pale haze
	# rather than the usual dark earth means tilting down shows more sky, not a
	# grey band under the island.
	sky_material.ground_bottom_color = Color(0.62, 0.74, 0.86)
	sky_material.ground_horizon_color = Color(0.78, 0.86, 0.93)
	sky_material.sun_angle_max = 22.0
	sky_material.sun_curve = 0.12

	var sky := Sky.new()
	sky.sky_material = sky_material

	environment.background_mode = Environment.BG_SKY
	environment.sky = sky

	# Ambient and reflections both sourced from that sky, so a colour change up
	# there propagates to the whole scene rather than needing three edits.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY


## ACES rather than linear, so bright emissive effects roll off into white
## instead of clipping to flat saturated blocks. Exposure slightly under 1 to
## leave headroom for the glow pass.
func _apply_tonemap() -> void:
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.95
	environment.tonemap_white = 3.0

	# A small saturation lift. The reference style is punchier than physically
	# correct lighting produces, and this is cheaper than hand-tuning 30 albedos.
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.14


## Bloom. The threshold matters more than the intensity: set it too low and the
## whole board hazes over, killing the crisp silhouettes the art depends on.
## At 1.05 only genuinely emissive things bloom - beams, muzzle flashes, spawn
## and goal markers, enemy eyes - exactly the set that should draw the eye.
func _apply_glow() -> void:
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.7
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.12
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.glow_hdr_threshold = 1.05
	environment.glow_hdr_scale = 2.0

	# Weight the mid levels. Level 1 is a tight halo that mostly aliases; the
	# 3-5 range is the soft spread that reads as light spilling.
	#
	# set_glow_level() is ZERO-indexed even though the inspector labels the same
	# slots "glow_levels/1".."glow_levels/7". Passing index + 1 shifted every
	# weight up a level - so the tight aliasing halo the array deliberately zeroes
	# was running at 0.25 - and then failed outright on the seventh, which is the
	# out-of-bounds error the autoplay gate has been printing on startup.
	var levels := [0.0, 0.25, 0.9, 1.0, 0.7, 0.35, 0.15]
	for index in levels.size():
		environment.set_glow_level(index, float(levels[index]))


## Contact shadows in the crevices between terrain slabs and under towers.
## This is what stops objects looking like stickers on the ground - more so
## than the directional shadow, which only catches one angle.
func _apply_ambient_occlusion() -> void:
	if _quality == Quality.LOW:
		return
	environment.ssao_enabled = true
	environment.ssao_radius = 1.1
	environment.ssao_intensity = 1.8
	environment.ssao_power = 1.6
	environment.ssao_detail = 0.4
	environment.ssao_horizon = 0.06
	environment.ssao_light_affect = 0.15

	if _quality == Quality.HIGH:
		# Indirect colour bleed - green from the grass onto tower bases. Subtle,
		# but it ties objects to the ground they stand on.
		environment.ssil_enabled = true
		environment.ssil_intensity = 0.5
		environment.ssil_radius = 2.5


## Real global illumination via SDFGI - light bouncing off surfaces rather than
## a flat ambient term. On this board that means green bleeding up from the
## grass onto tower bases and warm light filling the recessed path, which is
## what stops the shadowed side of everything reading as the same grey.
##
## It is genuinely expensive - the single most costly thing in this file - and
## it needs a moment to settle when the camera moves a long way, which is why
## the cascades are kept tight around the playable area rather than covering
## the horizon. If the frame rate is a problem, this is what to turn off first.
func _apply_global_illumination() -> void:
	if _quality != Quality.HIGH:
		return
	environment.sdfgi_enabled = true
	# Four cascades at a 1.2m cell covers roughly the board plus its border,
	# which is the only region the player looks at closely.
	environment.sdfgi_cascades = 4
	environment.sdfgi_min_cell_size = 1.2
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_bounce_feedback = 0.6
	environment.sdfgi_energy = 1.0
	environment.sdfgi_normal_bias = 1.1
	# The sky already supplies plenty of ambient, so SDFGI's own sky
	# contribution is dialled back to avoid washing the shadows out entirely.
	environment.sdfgi_read_sky_light = true


## Screen-space reflections. Honest assessment: on matte terrain these do
## almost nothing, which is why they are the first thing cut. They earn their
## cost on the metal tower plating and the glowing crystal props.
func _apply_reflections() -> void:
	if _quality != Quality.HIGH:
		return
	environment.ssr_enabled = true
	environment.ssr_max_steps = 32
	environment.ssr_fade_in = 0.2
	environment.ssr_fade_out = 2.5
	environment.ssr_depth_tolerance = 0.3


## Light aerial perspective, matched to the sky horizon so distance reads as
## haze rather than as a grey wash.
##
## Density is deliberately low. It was four times this when the backdrop was a
## ring of mountains that needed hiding; a floating island wants the opposite -
## the underside, the stalactites and the cloud deck below are the whole point,
## and fogging them out would remove the thing that makes it read as floating.
func _apply_fog() -> void:
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.76, 0.87, 0.96)
	environment.fog_light_energy = 1.0
	environment.fog_density = 0.0022
	environment.fog_sky_affect = 0.0
	environment.fog_aerial_perspective = 0.35


# ---------------------------------------------------------------------------
# Lights
# ---------------------------------------------------------------------------

func _build_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ROTATION
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.35
	sun.light_specular = 0.6

	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	# The board plus its border ring is about 55 units across. Anything beyond
	# that is fog, so spending shadow resolution on it is waste.
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.16
	sun.directional_shadow_split_3 = 0.45

	# Bias tuned for the terrain slabs specifically. Too low and the flat tops
	# get shadow acne; too high and towers detach from their own shadows.
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.4
	sun.shadow_blur = 1.0 if _quality == Quality.LOW else 1.4

	# The real softener. Giving the sun an angular size gives shadows a penumbra
	# that widens with distance from the caster, which is most of the difference
	# between "3D render" and "hard-edged 2001 shadow map".
	sun.light_angular_distance = 1.6

	add_child(sun)


func _build_fill() -> void:
	fill = DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = FILL_ROTATION
	fill.light_color = Color(0.62, 0.74, 0.95)
	fill.light_energy = 0.4
	fill.light_specular = 0.1
	# No shadows: a second shadow-casting light doubles the cost and produces
	# crossing shadows that read as a rendering bug rather than as sky light.
	fill.shadow_enabled = false
	add_child(fill)


# ---------------------------------------------------------------------------
# Runtime tuning
# ---------------------------------------------------------------------------

## Lets a settings menu drop quality without rebuilding the level.
func set_quality(quality: Quality) -> void:
	_quality = quality
	environment.ssao_enabled = quality != Quality.LOW
	environment.ssil_enabled = quality == Quality.HIGH
	environment.ssr_enabled = quality == Quality.HIGH
	environment.sdfgi_enabled = quality == Quality.HIGH
	sun.shadow_blur = 1.0 if quality == Quality.LOW else 1.4
	sun.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_ORTHOGONAL if quality == Quality.LOW
		else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
