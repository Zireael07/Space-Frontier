shader_type canvas_item;

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
	
	//colorize the CPU noise
	vec4 col_noise = texture(TEXTURE, UV);
	vec4 col_planet = vec4(1.0);
	if (col_noise.b > 0.45) {
		col_planet = vec4(0.0, 1.0, 1.0, 1.0);
	}
	else {
		col_planet = vec4(0.0, 1.0, 0.0, 1.0);
	}

	//output to screen
	COLOR = vec4(col_planet.rgb, planet);
	
}