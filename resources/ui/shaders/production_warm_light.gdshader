shader_type canvas_item;
render_mode unshaded;

uniform vec4 light_color : source_color = vec4(1.0, 0.67, 0.24, 0.22);


void fragment() {
	float distance_from_source = distance(UV, vec2(0.62, 0.88));
	float glow = 1.0 - smoothstep(0.06, 0.76, distance_from_source);
	float left_fade = smoothstep(0.12, 0.40, UV.x);
	COLOR = vec4(light_color.rgb, light_color.a * glow * left_fade);
}
