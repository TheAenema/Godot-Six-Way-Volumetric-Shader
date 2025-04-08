
/*   Six-Way Volumetric Lighting for Godot v2.0     */
/*            Developed by Hamid.Memar              */
/*   License : Creative Commons (CC) BY-NC-ND 4.0   */

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
uniform bool billboard = false;
uniform bool animate = false;
uniform float animate_speed = 30.0;
uniform float animate_offset = 0.0;
uniform vec2 flipbook_dimensions = vec2(2, 2);

// Utilities
mat4 look_at(vec3 from, vec3 to, vec3 up) {
    vec3 forward = normalize(to - from);
    vec3 right = normalize(cross(up, forward));
    vec3 new_up = cross(forward, right);

    mat4 result = mat4(1.0);
    result[0].xyz = right;
    result[1].xyz = new_up;
    result[2].xyz = forward;
    return result;
}
vec2 flipbook(vec2 uv, vec2 size, float progress)
{
	progress = floor(mod(progress, size.x * size.y));
	vec2 frame_size = vec2(1.0) / size;
	vec2 frame = fract(uv) * frame_size;
	frame.x += (mod(progress, size.x)) * frame_size.x;
	frame.y += floor(progress / size.x) * frame_size.y;
	return frame;
}

// Vertex Render
void vertex()
{
    if (billboard)
	{
        vec3 camera_pos = (INV_VIEW_MATRIX)[3].xyz;
        vec3 object_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
        vec3 to_camera = normalize(camera_pos - object_pos);
        vec3 up = vec3(0.0, 1.0, 0.0);
        vec3 right = normalize(cross(up, to_camera));
        vec3 new_up = cross(to_camera, right);
        mat3 rotation_matrix = mat3(right, new_up, to_camera);
        NORMAL = rotation_matrix * NORMAL;
        TANGENT = rotation_matrix * TANGENT;
        BINORMAL = rotation_matrix * BINORMAL;
        VERTEX = (rotation_matrix * VERTEX);
    }
}

// Pixel Render
void fragment()
{
	// Calculate UV
	vec2 uv = vec2(1.0);
	if (animate) uv = flipbook(UV, flipbook_dimensions, TIME * animate_speed + animate_offset);
	else uv = UV;

	// Calculate Pixel Rendering
	vec3 ao = mix(vec3(1.0), texture(six_way_map_TEA, uv).bbb, ao_power);
	ALBEDO = absorption * ao;
    ALPHA = texture(six_way_map_TEA, uv).r * density;
	vec3 normal_map_sample = texture(normal_map, uv).rgb * 2.0 - 1.0;
	vec3 normals = TANGENT * normal_map_sample.x + BINORMAL * normal_map_sample.y + NORMAL * normal_map_sample.z;
	NORMAL_MAP = mix(vec3(.5,.5,1.0), normals, normal_power);

	// Create Emission
    float emission_strength = texture(six_way_map_TEA, uv).g;  // Mono emission channel (black = no emission, white = max emission)
    vec3 emission_color = texture(emission_ramp, vec2(emission_strength, 0.0)).rgb * emission_strength * emission_power;
    EMISSION = emission_color;
}

// Light Render
void light()
{
	// Calculate UV
	vec2 uv = vec2(1.0);
	if (animate) uv = flipbook(UV, flipbook_dimensions, TIME * animate_speed + animate_offset);
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
    vec3 final_color = blended_color * (1.0 - (scattering / 5.0)) + (scattering / 5.0) * vec3(1.0, 1.0, 1.0); // Soft light scattering

	// Compute Absorption/Transmittance using a Simplified Beer's Law
	vec3 transmittance = exp(-absorption * thickness);

	// Modulate Light by Transmittance
	final_color = final_color * transmittance;

	// Final Result
    DIFFUSE_LIGHT += (final_color * LIGHT_COLOR * ATTENUATION / 4.4);
}
