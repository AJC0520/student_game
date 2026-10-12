shader_type spatial;
// Applied to the inverted-hull shell exported from Blender. Back faces are culled, so only the rim shows.
render_mode unshaded, cull_back;

uniform vec4 outline_color : source_color = vec4(0.05, 0.04, 0.09, 1.0);  // line colour

void fragment() {
	ALBEDO = outline_color.rgb;
}
