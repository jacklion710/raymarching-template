// Camera utilities and depth of field effects

// DoF configuration parameters
struct DoFConfig {
	float aperture;        // Size of the aperture (blur amount)
	float blades;          // Number of aperture blades (6 = hexagon, 5 = pentagon)
	float bladeRotation;   // Rotation of the bokeh shape in radians
	float temporalSpeed;   // Speed of temporal jitter (0 = disabled)
	float temporalAmount;  // Amount of temporal rotation (0-1 range recommended)
};

// Default DoF configuration
DoFConfig getDefaultDoFConfig() {
	return DoFConfig(
		0.12,   // aperture
		6.0,    // blades (hexagon)
		0.0,    // bladeRotation
		60.0,   // temporalSpeed
		0.12    // temporalAmount
	);
}

// Returns the radius of a regular polygon at a given angle
// Used to shape circular bokeh into polygon shapes (hexagon, pentagon, etc.)
float polygonRadius(float angle, float blades, float rotation) {
	float segment = 6.28318530718 / blades;
	float a = mod(angle + rotation, segment) - segment * 0.5;
	return cos(segment * 0.5) / cos(a);
}

// Calculates DoF ray offset using Fibonacci spiral sampling with polygon shaping
// sampleIndex: current sample index in the DoF loop
// sampleCount: total number of DoF samples
// camMat: camera matrix for orienting the offset in camera space
// config: DoF configuration parameters
// time: current time for temporal jitter (pass 0 to disable)
// Returns: offset vector to add to ray origin
vec3 getDoFOffset(int sampleIndex, int sampleCount, mat3 camMat, DoFConfig config, float time) {
	// No offset for first sample or single sample (allows clean center ray)
	if (sampleIndex == 0 || sampleCount <= 1) {
		return vec3(0.0);
	}
	
	// Fibonacci spiral sampling for even distribution
	float goldenAngle = 2.399963229728653;  // pi * (3 - sqrt(5))
	
	// Temporal jitter rotates the sample pattern each frame
	float temporalOffset = 0.0;
	if (config.temporalSpeed > 0.0) {
		temporalOffset = fract(time * config.temporalSpeed) * goldenAngle * config.temporalAmount;
	}
	
	float angle = float(sampleIndex) * goldenAngle + temporalOffset;
	float radius = sqrt(float(sampleIndex) / float(sampleCount)) * config.aperture;
	
	// Shape the disc into a polygon
	radius *= polygonRadius(angle, config.blades, config.bladeRotation);
	
	// Return offset in camera space
	return camMat * vec3(cos(angle) * radius, sin(angle) * radius, 0.0);
}

// Simplified DoF offset using default configuration
vec3 getDoFOffset(int sampleIndex, int sampleCount, mat3 camMat, float aperture, float time) {
	DoFConfig config = getDefaultDoFConfig();
	config.aperture = aperture;
	return getDoFOffset(sampleIndex, sampleCount, camMat, config, time);
}

// Shades a surface hit with lighting, fresnel, and reflection
// hitPos: world position of the ray hit
// rd: ray direction
// material: surface material color
// bgCol: background color for reflections
// Returns: final shaded color
vec3 shadeHit(vec3 hitPos, vec3 rd, vec3 material, vec3 bgCol) {
	vec3 normals = getNorm(hitPos);
	
	// Get material properties
	float metallic = gMaterial.metallic;
	float roughness = gMaterial.roughness;
	
	// Fresnel with metallic influence (Schlick approximation)
	// Metals have high base reflectivity, dielectrics have low (~0.04)
	float F0 = mix(0.04, 0.9, metallic);
	float cosTheta = max(dot(normals, -rd), 0.0);
	float fresnel = F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
	
	// Roughness heavily reduces reflection (rough surfaces scatter light)
	float roughnessDampen = (1.0 - roughness) * (1.0 - roughness);  // Quadratic falloff
	float reflectionStrength = fresnel * roughnessDampen;
	
	// Direct lighting - reduced for highly reflective surfaces
	vec3 col = getLight(hitPos, rd, material, normals) * (1.0 - reflectionStrength * 0.7);

	// Skip reflections entirely for very rough surfaces (roughness > 0.85)
	if (roughness < 0.85) {
		vec3 R = reflect(rd, normals);
		vec3 reflRo = hitPos + normals * (MIN_DIST * 4.0);
		vec3 reflColor = getFirstReflection(reflRo, R, bgCol);
		vec3 reflTint = mix(vec3(1.0), material, metallic * 0.5);  // Subtle tint for metals
		col += reflColor * reflTint * reflectionStrength;
	}

	return col;
}

// O(1): Lens flare calculation.
// rd: ray direction
// ro: ray origin
// lightPos: light position
// lightCol: light color (RGB intensity)
vec3 getLensFlare(vec3 rd, vec3 ro, vec3 lightPos, vec3 lightCol, float expo){
	float f = clamp(dot(rd, normalize(lightPos - ro)), 0.0, 1.0);
	f = pow(f, expo);
	return f * lightCol;
}
