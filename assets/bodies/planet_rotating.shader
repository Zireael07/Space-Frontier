shader_type canvas_item;

//based on https://github.com/meric/renderplanet

const float M_PI = 3.1415926535897932384626433832795;
uniform sampler2D vectors; //orthographic projection
uniform float rotate_angle;
//uniform float light_angle;
//2.0 is a full rotation
uniform float time : hint_range(0,2.0) = 1.0;

//uniform vec4 color : hint_color;

mat2 rotate2d(float _angle) {
    return mat2(vec2(cos(_angle), -sin(_angle)), vec2(sin(_angle), cos(_angle)));
}

void fragment(){
	bool has_rotate_matrix = false;
	mat2 rotate_planet_matrix;
	mat2 rotate_light_matrix;
  // Rotate planet
  //if (!has_rotate_matrix) {
    rotate_planet_matrix = rotate2d(rotate_angle);
    //rotate_light_matrix = rotate2d(light_angle + M_PI/4.0);
   // has_rotate_matrix = true;
  //}
  vec2 rotated_coords = rotate_planet_matrix * (UV-vec2(0.5));
  rotated_coords += vec2(0.5);
  vec4 vector = texture(vectors, rotated_coords );

  // Retrieve planet texture pixel
  vec2 planet_coords;
  planet_coords.x = (vector.r + vector.g/255.0 + time)/2.0;
  planet_coords.y = vector.b + vector.a/255.0;
  if (planet_coords.x > 1.0) {
    planet_coords.x =  planet_coords.x - 1.0;
  }
  // Calculate shadow.
//  vec2 light_coords = vec2(0, 0);
//  vec2 shadow_coords = UV;
//  shadow_coords -= vec2(0.5);
//  light_coords -= vec2(0.5);
//  light_coords = rotate_light_matrix * light_coords;
//  float shadow = 0.0;
//  shadow = 1.0-pow(distance(light_coords, shadow_coords)*0.9, 3);
//  if (shadow < 0.05) {
//    shadow = 0.05;
//  }

  if (distance(rotated_coords, vec2(0.5, 0.5)) > 0.5) {
    //return vector;
	COLOR = vector;
  }
  else {
  	COLOR = texture(TEXTURE, planet_coords);
  }
}
