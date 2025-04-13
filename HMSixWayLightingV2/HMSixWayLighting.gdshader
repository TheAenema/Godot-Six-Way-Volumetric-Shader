
/*   Six-Way Volumetric Lighting for Godot v2.3     */
/*            Developed by Hamid.Memar              */
/*      License : Creative Commons (CC) BY 4.0      */

// Shader Configuration
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always;

// Shader Parameters
uniform sampler2D six_way_map_RTB : source_color;
uniform sampler2D six_way_map_LBF : source_color;
uniform sampler2D six_way_map_TEA : source_color;
uniform sampler2D normal_map : hint_normal;
uniform sampler2D emission_ramp : source_color;
uniform vec3 absorption : source_color = vec3(1.0, 1.0, 1.0);
uniform float thickness : hint_range(-10, 10) = 0.15;
uniform float density : hint_range(0, 1) = 1.0;
uniform float scattering : hint_range(0, 1) = 0.0;
uniform float normal_power : hint_range(0, 1) = 0.25;
uniform float normal_blend : hint_range(0.0, 1.0) = 0.25;
uniform float ao_power : hint_range(0.0, 1.0) = 0.5;
uniform float emission_power : hint_range(0.0, 10.0) = 1.0;
uniform float emission_color_shift : hint_range(0.0, 360.0) = 1.0;
uniform int billboard_mode : hint_enum("Disabled", "Y-Axis", "Full") = 0;
uniform bool billboard_keep_scale = true;
uniform bool animate = false;
uniform float animate_speed = 30.0;
uniform float animate_offset = 0.0;
uniform ivec2 flipbook_dimensions = ivec2(2, 2);

// Animator
vec2 animateUV(vec2 uv, ivec2 size, float progress)
{
        progress = floor(mod(progress, float(size.x * size.y)));
        vec2 frame_size = vec2(1.0) / vec2(size);
        vec2 frame = fract(uv) * frame_size;
        frame.x += (mod(progress, float(size.x))) * frame_size.x;
        frame.y += float(int(progress) / size.x) * frame_size.y;
        return frame;
}
vec3 shiftColor(vec3 color, float shiftAngle)
{
	float Y = dot(color, vec3(0.299, 0.587, 0.114));
	float I = dot(color, vec3(0.596, -0.274, -0.322));
	float Q = dot(color, vec3(0.211, -0.523, 0.312));
	float rad = radians(shiftAngle);
	float cosA = cos(rad);
	float sinA = sin(rad);
	float newI = I * cosA - Q * sinA;
	float newQ = I * sinA + Q * cosA;
	return vec3(
		Y + 0.956 * newI + 0.621 * newQ,
		Y - 0.272 * newI - 0.647 * newQ,
		Y - 1.106 * newI + 1.703 * newQ
    	);
}

// Vertex Render
void vertex()
{

	// Y-Axis Billboard Only
	if (billboard_mode == 1)
	{
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), MAIN_CAM_INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
	}	
	
	// Full Billboard
	if (billboard_mode == 2)
	{
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			MAIN_CAM_INV_VIEW_MATRIX[0],
			MAIN_CAM_INV_VIEW_MATRIX[1],
			MAIN_CAM_INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]);
	}
	
	// Keep Size When Billboarding
	if (billboard_mode != 0 && billboard_keep_scale)
	{
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

// Pixel Render
void fragment()
{
	// Calculate UV
	vec2 uv = vec2(1.0);
	if (animate) uv = animateUV(UV, flipbook_dimensions, TIME * animate_speed + animate_offset);
	else uv = UV;
	
	// Calculate Pixel Rendering
	vec3 ao = mix(vec3(1.0), texture(six_way_map_TEA, uv).bbb, ao_power);
	ALBEDO = absorption * ao;
	ALPHA = texture(six_way_map_TEA, uv).r * density;
	vec3 normal_map_sample = texture(normal_map, uv).rgb * 2.0 - 1.0;
	vec3 normals = TANGENT * normal_map_sample.x + BINORMAL * normal_map_sample.y + NORMAL * normal_map_sample.z;
	NORMAL_MAP = mix(vec3(.5,.5,1.0), normals, normal_power);
	
	// Create Emission
	float emission_strength = texture(six_way_map_TEA, uv).g;
	vec3 emission_color = texture(emission_ramp, vec2(emission_strength, 0.0)).rgb * emission_strength * emission_power;
	EMISSION = shiftColor(emission_color, emission_color_shift);
}

// Light Render
void light()
{
	// Calculate UV
	vec2 uv = vec2(1.0);
	if (animate) uv = animateUV(UV, flipbook_dimensions, TIME * animate_speed + animate_offset);
	else uv = UV;
	
	// Get Light Direction
	vec3 light_dir = normalize(LIGHT);
	vec3 normal_dir = normalize(NORMAL);
	
	// Light-Direction Based Weights
	float weightXPos = max(light_dir.x, 0.0);
	float weightXNeg = max(-light_dir.x, 0.0);
	float weightYPos = max(light_dir.y, 0.0);
	float weightYNeg = max(-light_dir.y, 0.0);
	float weightZPos = max(light_dir.z, 0.0);
	float weightZNeg = max(-light_dir.z, 0.0);

	// Mix Weights
	float total = weightXPos + weightXNeg + weightYPos + weightYNeg + weightZPos + weightZNeg;
	if (total > 0.0) {
		weightXPos /= total;
		weightXNeg /= total;
		weightYPos /= total;
		weightYNeg /= total;
		weightZPos /= total;
		weightZNeg /= total;
	}

	// Sample 6-way Lightmap
	vec4 rtb = texture(six_way_map_RTB, uv);
	vec4 lbf = texture(six_way_map_LBF, uv);
	
	// Directional Lighting Result
	vec3 directional_color = weightXPos * vec3(rtb.r) + weightXNeg * vec3(lbf.r) +
	weightYPos * vec3(rtb.g) + weightYNeg * vec3(rtb.a) +
	weightZPos * vec3(lbf.b) + weightZNeg * vec3(rtb.b);
	
	// Normal Influence on Light
	float normal_strength = max(dot(normal_dir, light_dir), 0.0);
	
	// Interpolate: Pure Directional vs. Directional * Normal-Facing
	vec3 blended_color = mix(directional_color, directional_color * normal_strength, normal_blend);
	
	// Apply Fake Scattering Effect
	vec3 final_color = blended_color * (1.0 - (scattering / 5.0)) + (scattering / 5.0) * vec3(1.0, 1.0, 1.0);
	
	// Compute Absorption/Transmittance using a Simplified Beer's Law
	vec3 transmittance = exp(-absorption * thickness);
	
	// Modulate Light by Transmittance
	final_color = final_color * transmittance;
	
	// Final Result
	DIFFUSE_LIGHT += (final_color * LIGHT_COLOR * ATTENUATION / 4.4);
}
