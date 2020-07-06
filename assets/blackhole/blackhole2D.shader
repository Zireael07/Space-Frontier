shader_type canvas_item;

// Be gentle on this one
uniform float strength = 0.01;
uniform float black_radius = 0.85;

void fragment() {

	// Get direction and distance to the black hole center
	vec2 diff = vec2(0.5, 0.5) - vec2(UV.x, 1.0-UV.y);
	float d = length(diff)*2.0;
	vec2 dir = normalize(diff);
	float f = clamp(1.0-d, 0, 1);
	// This is a 0..1 value that will nullify the effect around the bounds of the effect,
	// for a seamless transition between the effect\'s area and the unaffected world pixels.
	float shelf = smoothstep(0, 1, f);
	// Calculate displacement amount
	float displacement = strength / (d*d + 0.01);
	// Calculate distorted screen-space texture coordinates
	vec2 uv = SCREEN_UV + dir * (displacement * shelf);
	// Output pixels from the screen using distorted UVs
	//vec3 col = texscreen(uv);
	vec3 col = texture(SCREEN_TEXTURE, uv).rgb;
	COLOR.rgb = mix(col, vec3(0,0,0), smoothstep(black_radius-0.01, black_radius+0.01, f));
	//COLOR.rgb = vec3(f, 0, 0);
}