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

// O(n): Estimate thickness for transmissive materials along a ray.
// startPos: starting point just inside the surface
// dir: normalized refraction direction
// Returns: approximate thickness through the object
float estimateTransmissionThickness(vec3 startPos, vec3 dir) {
	float thickness = 0.0;
	vec3 pos = startPos;
	for (int i = 0; i < 6; i++) {
		float d = getDist(pos).w;
		if (d > 0.002) {
			break;
		}
		float stepSize = clamp(-d, 0.02, 0.12);
		pos += dir * stepSize;
		thickness += stepSize;
	}
	return thickness;
}

// O(n): March through the interior of a transmissive object until exit.
// ro: starting point inside the object
// rd: refracted ray direction
// ior: index of refraction for exit calculation
// Returns: exit position, exit normal (outward), and distance traveled
void marchThroughObject(vec3 ro, vec3 rd, float ior, out vec3 exitPos, out vec3 exitNormal, out float thickness) {
	thickness = 0.0;
	vec3 pos = ro;
	
	for (int i = 0; i < 64; i++) {
		float d = getDist(pos).w;
		if (d > MIN_DIST * 2.0) {
			exitPos = pos;
			exitNormal = getNorm(pos);
			return;
		}
		float step = max(abs(d), 0.01);
		pos += rd * step;
		thickness += step;
		if (thickness > 2.0) break;
	}
	exitPos = pos;
	exitNormal = getNorm(pos);
}

// O(n): Trace refraction through a transmissive object (entry + exit).
// hitPos: entry point on surface
// rd: incoming ray direction
// normal: surface normal at entry (pointing outward)
// ior: index of refraction
// tint: material tint color
// bgCol: background color fallback
// Returns: color seen through the transparent object
vec3 traceRefraction(vec3 hitPos, vec3 rd, vec3 normal, float ior, vec3 tint, vec3 bgCol) {
	float eta = 1.0 / max(ior, 1.001);
	vec3 T = refract(rd, normal, eta);
	
	if (dot(T, T) < 0.0001) {
		return bgCol;
	}
	
	vec3 entryPos = hitPos - normal * (MIN_DIST * 10.0);
	
	vec3 exitPos, exitNormal;
	float thickness;
	marchThroughObject(entryPos, T, ior, exitPos, exitNormal, thickness);
	
	float etaExit = max(ior, 1.001);
	vec3 exitDir = refract(T, -exitNormal, etaExit);
	
	if (dot(exitDir, exitDir) < 0.0001) {
		exitDir = reflect(T, -exitNormal);
	}
	
	vec3 exitRo = exitPos + exitNormal * (MIN_DIST * 10.0);
	vec4 behindScene = map(exitRo, exitDir);
	float behindDist = behindScene.w;
	
	vec3 behindColor = bgCol;
	if (behindDist < farClip) {
		vec3 behindHit = exitRo + exitDir * behindDist;
		vec3 behindMat = behindScene.rgb;
		vec3 behindNorm = getNorm(behindHit);
		behindColor = getLight(behindHit, exitDir, behindMat, behindNorm) + gMaterial.emission;
	}
	
	vec3 absorption = exp(-(vec3(1.0) - tint) * thickness * 2.5);
	vec3 tintedColor = behindColor * absorption;
	tintedColor = mix(tintedColor, tintedColor * tint, 0.3);
	return tintedColor;
}

// O(n): Shades a surface hit with lighting, fresnel, and reflection.
// hitPos: world position of the ray hit
// rd: ray direction
// material: surface material color
// bgCol: background color for reflections
// Returns: final shaded color
vec3 shadeHit(vec3 hitPos, vec3 rd, vec3 material, vec3 bgCol) {
	vec3 normals = getNorm(hitPos);
	
	// Get material properties - save these before any calls that might overwrite gMaterial
	float metallic = gMaterial.metallic;
	float roughness = gMaterial.roughness;
	vec3 emission = gMaterial.emission;  // Save emission before getLight overwrites gMaterial
	float transmission = gMaterial.transmission;
	float ior = gMaterial.ior;
	
	// Fresnel with metallic influence (Schlick approximation)
	// Metals have high base reflectivity, dielectrics have low (~0.04)
	float F0 = mix(0.04, 0.9, metallic);
	float cosTheta = max(dot(normals, -rd), 0.0);
	float fresnel = F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
	
	// Roughness heavily reduces reflection (rough surfaces scatter light)
	float roughnessDampen = (1.0 - roughness) * (1.0 - roughness);  // Quadratic falloff
	float reflectionStrength = fresnel * roughnessDampen;
	
	// Calculate emission strength (0 = no glow, 1 = full glow)
	float emissionStrength = clamp(length(emission) / 3.0, 0.0, 1.0);
	
	// Direct lighting - reduced for emissive, reflective, and transmissive surfaces
	// Emissive objects don't need external lighting - they glow uniformly
	bool isTransmissive = transmission > 0.2;
	float transmissionDampen = isTransmissive ? 0.0 : 1.0;
	float lightingFactor = (1.0 - reflectionStrength * 0.7) * (1.0 - emissionStrength) * transmissionDampen;
	vec3 col = getLight(hitPos, rd, material, normals) * lightingFactor;

	vec3 reflectionCol = vec3(0.0);
#if RM_ENABLE_REFLECTIONS
	// Skip reflections for rough or highly emissive surfaces
	if (roughness < 0.85 && emissionStrength < 0.5) {
		vec3 R = reflect(rd, normals);
		vec3 reflRo = hitPos + normals * (MIN_DIST * 4.0);
		vec3 reflColor = getFirstReflection(reflRo, R, bgCol);
		vec3 reflTint = mix(vec3(1.0), material, metallic * 0.5);
		reflectionCol = reflColor * reflTint;
		float reflStrength = reflectionStrength;
		if (isTransmissive) {
			reflStrength *= 0.35;
		}
		col += reflectionCol * reflStrength;
	}
#endif

#if RM_ENABLE_REFRACTION
	if (transmission > 0.0 && ior > 1.0) {
		vec3 refrColor = traceRefraction(hitPos, rd, normals, ior, material, bgCol);
		
		float fresnelRefl = reflectionStrength;
		float fresnelTrans = 1.0 - fresnelRefl;
		
		col = refrColor * fresnelTrans + reflectionCol * fresnelRefl * 0.7;
		
		float edgeHighlight = pow(1.0 - max(dot(normals, -rd), 0.0), 4.0) * 0.15;
		col += vec3(edgeHighlight);
	}
#endif
	
	// Add emission (self-illumination) - this is the dominant color for glowing objects
	col += emission;

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
