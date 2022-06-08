shader_type canvas_item;
render_mode blend_premul_alpha;

//this shader only works properly with premultiplied alpha blend mode
uniform float aura_width = 2.0;
uniform vec4 aura_color:hint_color; 

void fragment(){
	vec4 col = texture(TEXTURE, UV);
	vec2 ps = TEXTURE_PIXEL_SIZE;
	float a;
	float maxa = col.a;
	float mina = col.a;
	
	a = texture(TEXTURE, UV + vec2(0, -aura_width)*ps).a;
	maxa = max(a, maxa); 
	mina = min(a, mina);
	
	a = texture(TEXTURE, UV + vec2(0, aura_width)*ps).a;
	maxa = max(a, maxa); 
	mina = min(a, mina);
	
	a = texture(TEXTURE, UV + vec2(-aura_width, 0)*ps).a;
	maxa = max(a, maxa); 
	mina = min(a, mina);
	
	a = texture(TEXTURE, UV + vec2(aura_width, 0)*ps).a;
	maxa = max(a, maxa); 
	mina = min(a, mina);
	
	//because premult alpha
	col.rgb *= col.a;
	
	COLOR = col;
	
	//COLOR = vec4(col.a, col.a, col.a, 0);
	float auraa = (maxa-mina);

	//if (auraa > 0.2)
	//{
	//	COLOR.rgb = aura_color.rgb*0.4;
	//	//COLOR.a = aura_color.a;
	//}

	//COLOR.rgb += aura_color.rgb*0.6;
	//COLOR.rgb = col.rgb*0.8 + aura_color.rgb*0.5;

	//normal outline
	COLOR.rgba = mix(col.rgba, aura_color.rgba, auraa);

	// haze over the planet itself
	if (col.a > 0.8)
	{
		COLOR.rgb = mix(col.rgb, aura_color.rgb, 0.3);
		//COLOR.a = 1.0;
	}

	// this affects the atmospheric semi-transparent outline in sprite
	if (col.a > 0.1 && col.a < 0.8)
	{
		//COLOR.rgb = vec3(aura_color.r, aura_color.g, aura_color.b);
		COLOR.rgba = mix(col.rgba, aura_color.rgba, 0.4);
	//	COLOR.a = aura_color.a;
	}

	//original
	//COLOR.rgb += aura_color.rgb*(auraa);
	
	//COLOR.rgb = vec3(0, 0, 0);
	//COLOR.rgb = vec3(UV.x, UV.y, 0);
	
	}
