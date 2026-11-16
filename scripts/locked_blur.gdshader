shader_type canvas_item;

// Frosted cover for a locked card's text (compendium.gd): the texture is
// already a blurred crop of the card; this greys it and washes it toward a
// flat tint so nothing underneath is readable.
uniform vec4 tint : source_color = vec4(0.32, 0.33, 0.37, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(grey), tint.rgb, tint_amount), 1.0);
}
