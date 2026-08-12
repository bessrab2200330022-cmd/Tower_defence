extends MeshInstance3D
## The highlight drawn on a single grid cell: hovered, selected, or refused.
##
## Corner brackets rather than a full box outline. A closed rectangle competes
## with the terrain slab seams already on the board and reads as another tile
## edge; brackets read as a cursor. The faint fill is what carries the colour,
## because at the RTS camera's distance a one-pixel outline is not enough to
## judge green from red at a glance - which is the entire job of this node.

const HOVER_HEIGHT: float = 0.07

const SHADER_SOURCE: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.4, 1.0, 0.55, 1.0);
// Bracket arm thickness, as a fraction of the half-cell.
uniform float thickness = 0.20;
// How far along each edge an arm runs from the corner. Below 0.5 the four arms
// stay separate, which is what makes it read as brackets rather than a frame.
uniform float arm = 0.42;
uniform float fill = 0.045;
uniform float pulse = 0.0;

void fragment() {
	// Distance from centre along each axis, 0 at the middle, 1 at the edge.
	vec2 p = abs(UV * 2.0 - 1.0);
	float outer = max(p.x, p.y);
	if (outer > 1.0) {
		discard;
	}

	// A point is on a bracket when it is inside the border band on one axis and
	// within `arm` of a corner on the other.
	float band_x = 1.0 - smoothstep(1.0 - thickness, 1.0 - thickness * 0.45, p.x);
	float band_y = 1.0 - smoothstep(1.0 - thickness, 1.0 - thickness * 0.45, p.y);
	float on_x = (1.0 - band_x) * step(1.0 - arm, p.y);
	float on_y = (1.0 - band_y) * step(1.0 - arm, p.x);
	float bracket = clamp(on_x + on_y, 0.0, 1.0);

	float wash = fill * (1.0 - outer * 0.35);
	float beat = 1.0 + pulse * 0.55 * sin(TIME * 9.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp((bracket + wash) * tint.a * beat, 0.0, 1.0);
}
"""

var _material: ShaderMaterial


func _init() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	plane.orientation = PlaneMesh.FACE_Y
	mesh = plane

	var shader := Shader.new()
	shader.code = SHADER_SOURCE
	_material = ShaderMaterial.new()
	_material.shader = shader
	material_override = _material

	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	visible = false


## `size` is the grid's cell size; the marker is inset slightly so two adjacent
## highlights do not touch.
func show_at(centre: Vector3, size: float, color: Color, pulsing: bool = false) -> void:
	position = Vector3(centre.x, HOVER_HEIGHT, centre.z)
	scale = Vector3(size * 0.92, 1.0, size * 0.92)
	_material.set_shader_parameter("tint", color)
	_material.set_shader_parameter("pulse", 1.0 if pulsing else 0.0)
	visible = true
