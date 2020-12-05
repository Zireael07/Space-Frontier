shader_type canvas_item;

//based on https://github.com/meric/renderplanet

const float M_PI = 3.1415926535897932384626433832795;
uniform sampler2D vectors; //orthographic projection
uniform float rotate_angle;
//uniform float light_angle;
//2.0 is a full rotation
uniform float time : hint_range(0,2.0) = 1.0;
uniform bool has_lights = true;


//uniform vec4 color : hint_color;

mat2 rotate2d(float _angle) {
    return mat2(vec2(cos(_angle), -sin(_angle)), vec2(sin(_angle), cos(_angle)));
}

// based on https://www.shadertoy.com/view/lscczl
float df_line( in vec2 a, in vec2 b, in vec2 p)
{
    vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa,ba) / dot(ba,ba), 0., 1.);	
	return length(pa - ba * h);
}

//  1 out, 2 in...
float hash12(vec2 p)
{
    vec3 p3  = fract(vec3(p.xyx) * .1031); //HASHSCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

///  2 out, 2 in...
vec2 hash22(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973)); //HASHSCALE3);
    p3 += dot(p3, p3.yzx+19.19);
    return fract((p3.xx+p3.yz)*p3.zy);

}

float rexp(vec2 p) {
	return (-log(1e-4 + (1. - 2e-4) * hash12(p)));
}

//https://www.shadertoy.com/view/lscczl
float line(vec2 a, vec2 b, vec2 uv, float width) {
    //float r1 = .04;
    float r1 = 0.1;
	float r2 = 0.08;
	//float r2 = .01;

    float d = df_line(a, b, uv);
    float d2 = length(a-b);
    float fade = smoothstep(4.5, 1.5, d2); //orig 1.5

    //fade += smoothstep(.05, .02, abs(d2-.75));
    //fade += smoothstep(.5, .02, abs(d2-.75));
	return smoothstep(r1, r2, d)*fade;
}

//float line(vec2 a, vec2 b, vec2 p, float width) {
//    // http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
//    vec2 pa = p - a, ba = b - a;
//	float h = clamp(dot(pa,ba) / dot(ba,ba), 0., 1.);	
//    float d = length(pa - ba * h);
//    float x = distance(p,a) / (distance(p,a) + distance(p,b));
//    return 2.5 * mix(rexp(a), rexp(b), x) * smoothstep(width/2., 0., d) * smoothstep(1.0, 0.5, distance(a,b));
//}

float network(vec2 p, float width) {
	vec2 N = vec2( 0, 1);
	vec2 E = vec2( 1, 0);
	vec2 S = vec2( 0,-1);
	vec2 W = vec2(-1, 0);
	
    // based on https://www.shadertoy.com/view/lscczl
    vec2 c = floor(p) + hash22(floor(p));
    vec2 n = floor(p) + N + hash22(floor(p) + N);
    vec2 e = floor(p) + E + hash22(floor(p) + E);
    vec2 s = floor(p) + S + hash22(floor(p) + S);
    vec2 w = floor(p) + W + hash22(floor(p) + W);
    
    float m = 0.;
    m += line(n, e, p, width);
	m += line(e, s, p, width);
    m += line(s, w, p, width);
    m += line(w, n, p, width);
   
    for (float y = -1.; y <= 1.; y++) {
        for (float x = -1.; x <= 1.; x++) {
            vec2 q = floor(p) + vec2(x,y) + hash22(floor(p) + vec2(x,y));
            float intensity = distance(p,q) / clamp(rexp(floor(p) + vec2(x,y)), 0., 1.);
            //float intensity = distance(p,q);
			m += line(c, q, p, width); //*10000.0);
            m += 10. * exp(-40. * intensity);
			//m *= intensity;
        }
    }
    
    return m;
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
	vec4 col = texture(TEXTURE, planet_coords);
	if (has_lights) {
		vec4 lights = vec4(0.95, 0.76, 0.47, 1.0);
		//vec4 lights = vec4(1.0, 0.0, 0.0, 1.0);
		float density = 0.5;
		float d = 1.0;
		float width = 3e-3;
		//float width = 6e-6;
		float net = network(100. * planet_coords + 1.0, 100. * width);
		d = density * net;
		
		//eliminate snow caps from equation
		float sn_fact = step(0.25, 1.-col.g);
		//find land masses
		float r_fact = step(0.15, col.r);
		float g_fact = step(0.25, col.g);
		float fact = (r_fact+g_fact)*sn_fact; //*sn_fact); //g_fact*sn_fact);
		//float fact = clamp(0.0, 1.0, col.g); //+col.g;
		col = mix(col, lights, fact*d); 
		//col = vec4(0.0, 1.0, 0.0, g_fact+r_fact);
		//col = mix(col, lights, 1.0-col.b);
	}
	COLOR = col;
  	//COLOR = texture(TEXTURE, planet_coords);
  }
}
