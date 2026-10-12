shader_type spatial;
// Cel shading: stepped diffuse, no specular. Ambient light (set on the Environment) gives the shadow tone.

uniform vec4 albedo : source_color = vec4(1.0);          // base colour (set per material by scripts/level.gd)
uniform float step1 : hint_range(0.0, 1.0) = 0.25;       // N.L below this = shadow band (ambient only)
uniform float step2 : hint_range(0.0, 1.0) = 0.55;       // N.L below this = mid band
uniform float mid_light : hint_range(0.0, 1.0) = 0.18;   // light added in the mid band
uniform float full_light : hint_range(0.0, 1.0) = 0.38;  // light added in the fully lit band

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float d = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float s = d < step1 ? 0.0 : (d < step2 ? mid_light : full_light);
	DIFFUSE_LIGHT += LIGHT_COLOR * s;
}
