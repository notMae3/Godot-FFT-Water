shader_type spatial;
render_mode shadows_disabled, cull_back;

global uniform sampler2DArray displacement_textures;
global uniform sampler2DArray displacement_textures_mipmap;
global uniform sampler2DArray slope_textures;
global uniform sampler2DArray slope_textures_mipmap;

group_uniforms Mesh_uniforms;
uniform int pass_layer;
uniform bool pass_layer_is_max;
uniform float vertex_scalar = 1.0; //! DEAL WITH THIS SHIT
uniform float mesh_size = 100.0; // either of the mesh's size vector components
uniform float mesh_default_size = 100.0;
uniform float mesh_layer_scale_factor = 2.0;

group_uniforms Mesh_uniforms.Sinking;
uniform float mesh_layer_sinking_slope_start = 0.255; // 0.23
uniform float mesh_layer_sinking_slope_end = 0.24; // 0.2
uniform float mesh_layer_sinking_factor = 7.5; // 2.0

group_uniforms Beach_interaction;
global uniform float beach_min;
global uniform float beach_max;
global uniform float beach_weight_scalar;

group_uniforms Normal_strengths;
uniform float normal_strength : hint_range(0.0, 20.0) = 0.5;
uniform float specular_normal_strength : hint_range(0.0, 5.0) = 1.0;

group_uniforms Depth_attunement;
uniform float depth_factor : hint_range(0.0, 250000.0, 500.0) = 47500.0;
uniform float displacement_depth_falloff : hint_range(0.0, 10.0) = 1.0;
uniform float normal_depth_falloff : hint_range(0.0, 10.0) = 1.0;
uniform float foam_depth_falloff : hint_range(0.0, 10.0) = 2.891;

group_uniforms Foam_uniforms;
uniform vec3 foam_color : source_color = vec3(0.9, 0.9, 0.9);
uniform float foam_roughness_modifier = 1.655;

group_uniforms PBR_uniforms;
uniform vec4 base_water_color : source_color = vec4(0.112, 0.23, 0.29, 1.0);
uniform vec3 scatter_color : source_color = vec3(0.246, 0.43, 0.45);
uniform vec3 bubble_color : source_color = vec3(0.0, 0.153, 0.133);
uniform float height_modifier : hint_range(0.0, 50.0) = 3.011;
uniform float wave_peak_scatter_strength : hint_range(0.0, 15.0) = 2.088;
uniform float scatter_strength : hint_range(0.0, 10.0) = 2.847;
uniform float scatter_shadow_strength : hint_range(0.0, 15.0) = 3.281;
uniform float bubble_density : hint_range(0.0, 10.0) = 0.46;
uniform float roughness : hint_range(0.001, 1.0) = 0.144;
uniform float specular_view_dependence : hint_range(0.0, 10.0) = 0.57;

// debug tools
group_uniforms Debug;
uniform bool[4] debug_layers;// = {true, false, false, false};
uniform float[4] water_layer_scale_factor; // = {1.225, 0.71, 1.93, 6.14}; // multiplies the sampling coords, meaning wide variety of repeat cycles and way less visible tiling
const bool[4] water_layer_displacement_contribution = {true, true, true, true};
uniform float[4] water_layer_foam_subtract;// = {0.0, 0.0, 0.16, 10.435};
global uniform bool visualize_beach_mask;

varying vec3 world_vertex;
varying float px_height;
varying float foam;
varying float camera_depth;
varying flat int mesh_sinking_at_lowest;
varying float beach_mask;

float lerp1(float a, float b, float f) {
	return a + f * (b - a);
}

vec3 lerp3(vec3 a, vec3 b, float f) {
	return a + f * (b - a);
}

float saturate1(float v) {
	return clamp(v, 0.0, 1.0);
}

float DotClamped(vec3 a, vec3 b) {
	return clamp(dot(a,b), 0.0, 1.0);
}

float SmithMaskingBeckmann(vec3 H, vec3 S, float roughness_) {
	float HdotS = max(0.001f, DotClamped(H, S));
	float a = HdotS / (roughness_ * sqrt(1.0 - HdotS * HdotS));
	float a2 = a * a;

	return a < 1.6f ? (1.0f - 1.259f * a + 0.396f * a2) / (3.535f * a + 2.181 * a2) : 0.0f;
}

float Linear01Depth(float z) {
	return 1.0 / (0.1 + depth_factor * z);
}

float Beckmann(float NdotH, float roughness_) {
	float exp_arg = (NdotH * NdotH - 1.0) / (roughness_ * roughness_ * NdotH * NdotH);

	return exp(exp_arg) / (PI * roughness_ * roughness_ * NdotH * NdotH * NdotH * NdotH);
}



vec4 sample_displacement_highres(vec2 sample_coords) {
	vec4 displacement1 = texture(displacement_textures, vec3(sample_coords * water_layer_scale_factor[0], 0)) * float(water_layer_displacement_contribution[0]); displacement1.a = max(0.0, displacement1.a-water_layer_foam_subtract[0]) ; displacement1 *= float(debug_layers[0]);
	vec4 displacement2 = texture(displacement_textures, vec3(sample_coords * water_layer_scale_factor[1], 1)) * float(water_layer_displacement_contribution[1]); displacement2.a = max(0.0, displacement2.a-water_layer_foam_subtract[1]) ; displacement2 *= float(debug_layers[1]);
	vec4 displacement3 = texture(displacement_textures, vec3(sample_coords * water_layer_scale_factor[2], 2)) * float(water_layer_displacement_contribution[2]); displacement3.a = max(0.0, displacement3.a-water_layer_foam_subtract[2]) ; displacement3 *= float(debug_layers[2]);
	vec4 displacement4 = texture(displacement_textures, vec3(sample_coords * water_layer_scale_factor[3], 3)) * float(water_layer_displacement_contribution[3]); displacement4.a = max(0.0, displacement4.a-water_layer_foam_subtract[3]) ; displacement4 *= float(debug_layers[3]);
	displacement2 *= beach_mask; // scales the largest waves by the beach proximity
	return displacement1 + displacement2 + displacement3 + displacement4;
}
vec2 sample_slopes_highres(vec2 sample_coords) {
	vec2 slopes1 = texture(slope_textures, vec3(sample_coords * water_layer_scale_factor[0], 0)).rg * float(debug_layers[0]);
	vec2 slopes2 = texture(slope_textures, vec3(sample_coords * water_layer_scale_factor[1], 1)).rg * float(debug_layers[1]);
	vec2 slopes3 = texture(slope_textures, vec3(sample_coords * water_layer_scale_factor[2], 2)).rg * float(debug_layers[2]);
	vec2 slopes4 = texture(slope_textures, vec3(sample_coords * water_layer_scale_factor[3], 3)).rg * float(debug_layers[3]);
	slopes2 *= beach_mask; // scales the largest waves by the beach proximity
	vec2 slopes = slopes1 + slopes2 + slopes3 + slopes4;
	slopes *= normal_strength;
	return slopes;
}
vec4 sample_displacement_lowres(vec2 sample_coords) {
	vec4 displacement1 = texture(displacement_textures_mipmap, vec3(sample_coords * water_layer_scale_factor[0], 0)) * float(water_layer_displacement_contribution[0]); displacement1.a = max(0.0, displacement1.a-water_layer_foam_subtract[0]) ; displacement1 *= float(debug_layers[0]);
	vec4 displacement2 = texture(displacement_textures_mipmap, vec3(sample_coords * water_layer_scale_factor[1], 1)) * float(water_layer_displacement_contribution[1]); displacement2.a = max(0.0, displacement2.a-water_layer_foam_subtract[1]) ; displacement2 *= float(debug_layers[1]);
	vec4 displacement3 = texture(displacement_textures_mipmap, vec3(sample_coords * water_layer_scale_factor[2], 2)) * float(water_layer_displacement_contribution[2]); displacement3.a = max(0.0, displacement3.a-water_layer_foam_subtract[2]) ; displacement3 *= float(debug_layers[2]);
	vec4 displacement4 = texture(displacement_textures_mipmap, vec3(sample_coords * water_layer_scale_factor[3], 3)) * float(water_layer_displacement_contribution[3]); displacement4.a = max(0.0, displacement4.a-water_layer_foam_subtract[3]) ; displacement4 *= float(debug_layers[3]);
	displacement2 *= beach_mask; // scales the largest waves by the beach proximity
	return displacement1 + displacement2 + displacement3 + displacement4;
}
vec2 sample_slopes_lowres(vec2 sample_coords) {
	vec2 slopes1 = texture(slope_textures_mipmap, vec3(sample_coords * water_layer_scale_factor[0], 0)).rg * float(debug_layers[0]);
	vec2 slopes2 = texture(slope_textures_mipmap, vec3(sample_coords * water_layer_scale_factor[1], 1)).rg * float(debug_layers[1]);
	vec2 slopes3 = texture(slope_textures_mipmap, vec3(sample_coords * water_layer_scale_factor[2], 2)).rg * float(debug_layers[2]);
	vec2 slopes4 = texture(slope_textures_mipmap, vec3(sample_coords * water_layer_scale_factor[3], 3)).rg * float(debug_layers[3]);
	slopes2 *= beach_mask; // scales the largest waves by the beach proximity
	vec2 slopes = slopes1 + slopes2 + slopes3 + slopes4;
	slopes *= normal_strength;
	return slopes;
}

void vertex() {
	//* multi-layered mesh displacement
	// mesh layer scaling
	VERTEX *= vertex_scalar;
	VERTEX /= pow(mesh_layer_scale_factor, float(pass_layer));
	
	// mesh layer height merging
	vec2 UV_centered = abs(UV - vec2(0.5));
	float mesh_sinking_y_displacement = smoothstep(mesh_layer_sinking_slope_start, mesh_layer_sinking_slope_end, length(UV_centered)) * float(!pass_layer_is_max);
	VERTEX.y -= mesh_sinking_y_displacement * mesh_layer_sinking_factor;
	mesh_sinking_at_lowest = int(mesh_sinking_y_displacement > 0.99);


	//* sample textures and scale effect by camera depth
	bool use_high_res = pass_layer_is_max;

	// calc camera depth
	vec4 clip_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	camera_depth = 1.0 - Linear01Depth(clip_pos.z / clip_pos.w);

	// calc world vertex to use when sampling textures
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz / mesh_size * (mesh_size/mesh_default_size);
	beach_mask = smoothstep(beach_min, beach_max, beach_weight_scalar * length(world_vertex.xz));

	// sample the displacement textures, which contain vec3 vertex displacement and float foam
	vec4 displacement = use_high_res ? sample_displacement_highres(world_vertex.xz) : sample_displacement_lowres(world_vertex.xz);
	vec3 vertex_displacement = lerp3(vec3(0.0), displacement.rgb, pow(saturate1(camera_depth), displacement_depth_falloff));
	VERTEX += vertex_displacement;

	// // sample slopes and calculate the normal, tangent and binormal
	vec2 slopes = use_high_res ? sample_slopes_highres(world_vertex.xz) : sample_slopes_lowres(world_vertex.xz);
	vec3 meso_normal = normalize(vec3(-slopes.x, 1.0f, -slopes.y));
	NORMAL = normalize(lerp3(vec3(0, 1, 0), meso_normal, pow(saturate1(camera_depth), normal_depth_falloff)));

	TANGENT = vec3(NORMAL.z, 0.0, -NORMAL.x);
	BINORMAL = cross(NORMAL, TANGENT);
}

void fragment() {
	// if this pixel isnt in view dont color it or do any light calculations
	// vec2 in_view_vec2 = step(abs(SCREEN_UV*2.0 - 1.0), vec2(1.0));
	// bool in_view = bool(in_view_vec2.x) && bool(in_view_vec2.y);
	// if (!in_view || bool(mesh_sinking_at_lowest)) discard;

	bool use_high_res = pass_layer_is_max;

	// fragment equivalent of vertex()'s world_vertex.xz. world_vertex samples for every vertex, modified_uv samples for every pixel
	// vec2 _scaled_uv = (UV-vec2(0.5)) * mesh_size / pow(mesh_layer_scale_factor, float(pass_layer));
	// vec2 modified_uv = (NODE_POSITION_WORLD.xz + _scaled_uv)/mesh_default_size;
	
	vec4 displacement = use_high_res ? sample_displacement_highres(world_vertex.xz) : sample_displacement_lowres(world_vertex.xz);
	px_height = displacement.y;

	foam = lerp1(0.0, saturate1(displacement.a), pow(camera_depth, foam_depth_falloff));
	ALBEDO = lerp3(base_water_color.rgb, foam_color, saturate1(foam));

	// enables godots built in SSR
	ROUGHNESS = 0.0;

	if (visualize_beach_mask) ALBEDO = vec3(beach_mask);
}

void light() {
	vec3 specular_normal = NORMAL;
	specular_normal.xz *= specular_normal_strength;
	specular_normal = normalize(specular_normal);

	vec3 halfway_dir = normalize(LIGHT + VIEW);
	float NdotL = DotClamped(NORMAL, LIGHT);
	float NdotH = max(0.0001, dot(specular_normal, halfway_dir));

	float a = roughness + foam * foam_roughness_modifier;
	float view_mask = SmithMaskingBeckmann(halfway_dir, VIEW, a);
	float light_mask = SmithMaskingBeckmann(halfway_dir, LIGHT, a);

	// geometry G
	float G = 1.0 / (1.0 + view_mask + light_mask);

	// refraction R
	float eta = 1.33;
	float R = ((eta - 1.0) * (eta - 1.0)) / ((eta + 1.0) * (eta + 1.0));

	// fresnel F
	float numerator = pow(1.0 - dot(specular_normal, VIEW), 5.0 * exp(-2.69 * a));
	float F = R + (1.0 - R) * numerator / (1.0f + 22.7f * pow(a, 1.5f));
	F = saturate1(F);

	vec3 sun_irradiance = LIGHT_COLOR / PI;
	vec3 specular = sun_irradiance * F * G * Beckmann(NdotH, a);
	specular *= specular_view_dependence * max(0.001f, DotClamped(vec3(0.0, 1.0, 0.0), LIGHT));
	specular *= NdotL;

	// Altas' scatter
	float H = max(0.0, px_height) * height_modifier;

	float k1 = wave_peak_scatter_strength * H * pow(DotClamped(LIGHT, -VIEW), 4.0f) * pow(0.5 - 0.5 * dot(LIGHT, NORMAL), 3.0);
	float k2 = scatter_strength * pow(DotClamped(VIEW, NORMAL), 2.0);
	float k3 = scatter_shadow_strength * NdotL;
	float k4 = bubble_density;

	vec3 scatter = (k1 + k2) * scatter_color * sun_irradiance * (1.0 / (1.0 + light_mask));
	scatter += k3 * scatter_color * sun_irradiance + k4 * bubble_color * sun_irradiance;


	DIFFUSE_LIGHT = (1.0 - F) * scatter;
	SPECULAR_LIGHT = specular;
}





//TODO
//# before compiling, when reading the FFT.glsl file, before get_spirv, open the file and set the local_group_x, SIZE and LOGSIZE
//# lowkey just remove LOGSIZE and calc it at runtime (?)
//- this enables the spectrum_texture_size variable to be an exposed uniform the user can set
//*- > do multiple FFT.glsl files with differing quality?

//- shrink the mesh by /2 as opposed to expand it
//- this fixes the culling issue i had earlier
//- also there might be a builtin variable that contains the pass-layer idx
//*- > culling doesnt work since mesh position isnt being set through shader

//- add mipmap gen

//# set the water mesh aabb height to max wave height through gdscript

// go through the compute shaders
// 		% _N in PackSpectrumConjugate

//! use special compact foam textures?
// 		actually might not be a great idea cos more data textures to sling around, however sampling would get cheaper
//* 	the foam res on smaller spectrum texture sizes is quite pixely

//! go through the gdc pres

// fix the foam fps issue

//- add custom env reflections

//- remember the report needs to have some substance by the seminar
//-		meh

























// mip fps data (Intel i5 8400, NVIDIA GTX 1070 8GB, 16GB DDR4 2667MHz)
// 512 + no mip: 275fps
// 512 + 2x mip: all mip: 360fps, dynamic mip: 320fps
// 512 + 4x mip: all mip: 410fps, dynamic mip: 360fps
// 512 + 8x mip: all mip: 435fps, dynamic mip: 380fps