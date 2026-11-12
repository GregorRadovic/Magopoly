shader_type canvas_item;

// Behind the large card picker (Magic Forest / Spell Shop): the game, blurred,
// greyed and darkened, so the picker stands out.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius = 6.0;
uniform vec3 tint = vec3(0.12, 0.12, 0.15);
uniform float tint_amount = 0.55;
uniform float desaturate = 0.7;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 sum = vec3(0.0);
	float total = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float w = 1.0 - length(vec2(float(x), float(y))) / 4.5;
			if (w > 0.0) {
				sum += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px).rgb * w;
				total += w;
			}
		}
	}
	vec3 c = sum / total;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(grey), desaturate);
	c = mix(c, tint, tint_amount);
	COLOR = vec4(c, 1.0);
}
