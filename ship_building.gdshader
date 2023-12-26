//based on https://godotshaders.com/shader/progress-bar-anything/
shader_type canvas_item;

uniform vec4 fill_color: source_color = vec4(1.0);
uniform float min_val;
uniform float current_val;
uniform float max_val;

/*
	linear normalization from one range to another
*/
float linear(float old_min, float old_max, float new_min, float new_max, float current) {
	float old_range = (old_max - old_min);
	float new_range = (new_max - new_min);
	float new_val = (((current - old_min) * new_range) / old_range ) + new_min;
	return new_val;
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 color = COLOR;
	
	float normalized = linear(min_val, max_val, 0.0, 1.0, current_val);
	
	/*
	If value is less than or equal to the calculated point
	between min and max that current_value falls on, mix with our
	fill color
	*/
	//we want it to grow bottom-up hence this calculation
	if (1.0-UV.y >= normalized) {
	//if (UV.y >= normalized) {
		color.rgb = mix(color.rgb, fill_color.rgb, 0.5);
		//color.a = mix(0.0, 1.0, 1.0);
		//color.rgb = fill_color.rgb;
		color.a = 0.0;
	}
	
	COLOR = color;
}


void light() {
	// Called for every pixel for every light affecting the CanvasItem.
}
