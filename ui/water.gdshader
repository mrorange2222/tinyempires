shader_type canvas_item;
render_mode unshaded;

uniform vec2 board_size;
// Room for the largest generated island (10 x 10 land area).
const int MAX_LAND = 100;
uniform vec2 land_centers[MAX_LAND];
uniform int land_count = 0;
uniform float hex_radius = 76.0;
uniform float tilt = 0.58;

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 k = vec2(127.1, 311.7);
	float a = fract(sin(dot(cell, k)) * 43758.5453);
	float b = fract(sin(dot(cell + vec2(1.0, 0.0), k)) * 43758.5453);
	float c = fract(sin(dot(cell + vec2(0.0, 1.0), k)) * 43758.5453);
	float d = fract(sin(dot(cell + vec2(1.0), k)) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 p = UV * board_size;
	float shore_distance = 10000.0;
	for (int i = 0; i < MAX_LAND; i++) {
		if (i >= land_count) {
			break;
		}
		vec2 q = abs((p - land_centers[i]) / vec2(1.0, tilt));
		float edge = max(q.x, dot(q, vec2(0.5, 0.8660254)));
		shore_distance = min(shore_distance, edge - hex_radius * 0.8660254);
	}
	float broad = noise(p * 0.009);
	float detail = noise(p * vec2(0.045, 0.09));
	float depth = smoothstep(0.0, hex_radius * 0.75,
		shore_distance + (broad - 0.5) * 8.0);
	vec3 shallow = vec3(0.11, 0.38, 0.43);
	vec3 deep = vec3(0.035, 0.19, 0.30);
	vec3 water = mix(shallow, deep, depth);
	water += (broad - 0.5) * 0.035 + (detail - 0.5) * 0.012;
	float ripple = pow(0.5 + 0.5 * sin(p.y * 0.34 + noise(p * 0.025) * 9.0), 14.0);
	float ripple_patch = smoothstep(0.35, 0.75, noise(p * vec2(0.022, 0.065)));
	water += vec3(0.025, 0.045, 0.05) * ripple * ripple_patch;
	float foam = (1.0 - smoothstep(1.0, 5.0, abs(shore_distance - 3.0)));
	foam *= 0.14 + 0.22 * detail;
	water = mix(water, vec3(0.76, 0.88, 0.78), foam);
	COLOR = vec4(water, 1.0);
}
