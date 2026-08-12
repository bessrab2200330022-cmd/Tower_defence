extends MeshInstance3D
## A tower's range, drawn as a flat radial shader on the ground.
##
## Replaces the TorusMesh this used to be. A torus is a solid of revolution
## sitting half-buried in the terrain, so its lower surface is coplanar with the
## ground over a long, thin, view-dependent band - which is the textbook recipe
## for z-fighting, and it shimmered accordingly. A single quad lifted clear of
## the ground cannot z-fight with anything by construction, costs two triangles
## instead of a few hundred, and lets the ring do things geometry cannot: a soft
## edge, an interior wash, and a pulse when placement is refused.
##
## Purely presentational. It is told a radius; it never asks what the radius is.

## High enough to clear the terrain slabs and the recessed path, low enough that
## the parallax against the ground is not noticeable from the RTS camera angle.
const HOVER_HEIGHT: float = 0.09

const SHADER_SOURCE: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.45, 0.85, 1.0, 1.0);
// Half-width of the bright annulus, in normalised radius.
uniform float band = 0.017;
uniform float softness = 0.026;
// Faint wash across the covered area, so the ring reads as a footprint rather
// than as a hoop lying on the grass.
uniform float fill = 0.028;
// 0 = steady, 1 = full pulse. Driven when a placement is invalid.
uniform float pulse = 0.0;
uniform float intensity = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	if (d > 1.01) {
		discard;
	}
	float ring = 1.0 - smoothstep(band, band + softness, abs(d - 0.955));
	// Squared falloff on the wash: brightest under the tower, gone by the edge,
	// so two overlapping rings still read as two.
	float wash = fill * (1.0 - d) * (1.0 - d);
	float beat = 1.0 + pulse * 0.5 * sin(TIME * 9.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp((ring + wash) * tint.a * beat * intensity, 0.0, 1.0);
}
"""

var _material: ShaderMaterial


func _init() -> void:
	var plane := PlaneMesh.new()
	# Size 2 so a scale of R covers a diameter of 2R - the quad's half-width is
	# the radius, which is what the shader's normalised UV assumes.
	plane.size = Vector2(2.0, 2.0)
	plane.orientation = PlaneMesh.FACE_Y
	mesh = plane

	var shader := Shader.new()
	shader.code = SHADER_SOURCE
	_material = ShaderMaterial.new()
	_material.shader = shader
	material_override = _material

	# The ring is an overlay, not scenery: it must never cast a shadow or feed
	# the global illumination probe.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	visible = false


## Places the ring on the ground at `centre`, sized to `radius` world units.
func show_at(centre: Vector3, radius: float) -> void:
	position = Vector3(centre.x, HOVER_HEIGHT, centre.z)
	scale = Vector3(maxf(radius, 0.01), 1.0, maxf(radius, 0.01))
	visible = true


func set_tint(color: Color) -> void:
	_material.set_shader_parameter("tint", color)


## `invalid` pulses the ring. Used while a placement is refused, so the reason
## the ghost turned red is legible from the ring as well as the box.
func set_invalid(invalid: bool) -> void:
	_material.set_shader_parameter("pulse", 1.0 if invalid else 0.0)


## Dims the whole ring. A hovered tower shows a fainter ring than a selected
## one, so the two states are distinguishable without a second colour.
func set_intensity(value: float) -> void:
	_material.set_shader_parameter("intensity", value)
