shader_type spatial;
// Clear glass: unshaded so lamps/sun don't paint specular streaks on it, one layer only (back faces culled).
render_mode unshaded, blend_mix, cull_back, depth_draw_opaque;

uniform vec4 tint : source_color = vec4(0.7, 0.88, 0.97, 1.0);        // glass colour
uniform float base_alpha : hint_range(0.0, 1.0) = 0.14;                // opacity when looking straight through
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.35;                // extra opacity at grazing angles

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(base_alpha + fres * edge_alpha, 0.0, 1.0);
}
