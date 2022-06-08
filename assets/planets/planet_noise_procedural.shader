shader_type canvas_item;


uniform float rotate_perc : hint_range(0,1) = 0.1;

uniform float cut_off : hint_range(0,1) = 0.45;
uniform vec4 color_land : hint_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform vec4 color_sea : hint_color = vec4(0.0, 1.0, 1.0, 1.0);

uniform vec4 cloud_col: hint_color = vec4(0.9, 0.9, 0.9, 0.9);
uniform float cloud_intensity: hint_range(0,1) = 0.25;
uniform vec2 cloud_noise_scale = vec2(2,8);

mat2 rotate2d(float _angle) {
    return mat2(vec2(cos(_angle), -sin(_angle)), vec2(sin(_angle), cos(_angle)));
}

// from book of shaders ch 07
//this trick avoids both sqrt and multiplying
float circle(in vec2 _st, in float _radius){
    vec2 dist = _st-vec2(0.5);
	return 1.-smoothstep(_radius-(_radius*0.01),
                         _radius+(_radius*0.01),
                         dot(dist,dist)*4.0);
}


void fragment(){
	//planet centered
	float radius = 1.0; 
	float planet = circle(UV, radius);

	vec3 col = vec3(1.0);
	vec3 planet_col = col * planet;
	
	//COLOR = vec4(planet_col.rgb, 1.0);
	
	//6.3 seems to be a full rotation
	float rotate_angle = 6.3*rotate_perc;
	mat2 rotate_planet_matrix = rotate2d(rotate_angle);
	//vec2 rot = (UV-vec2(0.5)); // this makes it top-down
	//vec2 rot = (UV-vec2(0.0, 0.5)); //rotates on the side (like Uranus) = vertical axis
	vec2 rot = (UV-vec2(0.5, 0.0)); //rotates along the horizontal axis
	vec2 rotated_coords = rotate_planet_matrix * rot;
	//rotated_coords += vec2(0.5);
	vec2 uv = rotated_coords;
	//vec2 uv = UV;
	
	// add some shadow
	vec2 height_uv = uv;
	float height = texture(TEXTURE, height_uv).r;
	
	//colorize the CPU noise
	vec4 col_noise = texture(TEXTURE, uv);
	vec4 col_planet = vec4(1.0);
	if (col_noise.b > cut_off) {
		col_planet = color_land;
	}
	else {
		col_planet = color_sea;
	}

	//output to screen
	//COLOR = vec4(height);
	// mix in some height/shading
	vec4 colr = mix(vec4(col_planet.rgb, planet), vec4(0.0, 0.0, 0.0, planet), height);
	//COLOR = vec4(col_planet.rgb, planet);
	
	//added some clouds based on https://github.com/Zarkonnen/GenGen
	vec4 cloud_noise = texture(TEXTURE, UV*cloud_noise_scale);
	float cloudN = max(0.0, cloud_noise.r);
	//vec4 clouds_clr = cloudiness * (1.0-cloudN) + cloud_col * cloudN;
	vec4 clouds_clr = cloud_col * (1.0 - cloudN) + cloud_intensity * cloudN;
	
	//colr = colr * clouds_clr;
	colr = mix(colr, clouds_clr, min(planet, clouds_clr.a));
	
	COLOR = colr;
}
