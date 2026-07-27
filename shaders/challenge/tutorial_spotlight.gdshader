shader_type canvas_item;

uniform int target_count = 0;
uniform vec4 target_0 = vec4(0.0);
uniform vec4 target_1 = vec4(0.0);
uniform vec4 target_2 = vec4(0.0);
uniform vec4 target_3 = vec4(0.0);
uniform vec4 dim_color : source_color = vec4(0.06, 0.035, 0.11, 0.72);

bool inside_rect(vec2 point, vec4 rect) {
	return point.x >= rect.x
		&& point.y >= rect.y
		&& point.x <= rect.x + rect.z
		&& point.y <= rect.y + rect.w;
}

void fragment() {
	bool spotlight = false;
	if (target_count > 0) spotlight = spotlight || inside_rect(UV, target_0);
	if (target_count > 1) spotlight = spotlight || inside_rect(UV, target_1);
	if (target_count > 2) spotlight = spotlight || inside_rect(UV, target_2);
	if (target_count > 3) spotlight = spotlight || inside_rect(UV, target_3);
	COLOR = spotlight ? vec4(0.0) : dim_color;
}
