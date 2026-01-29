// Material definitions and utilities

struct Material {
	vec3 albedo;       // Base color
	float metallic;    // 0 = dielectric (plastic, wood), 1 = metal (gold, iron)
	float roughness;   // 0 = mirror smooth, 1 = fully diffuse
	vec3 emission;     // Self-illumination color (black = no glow)
	float iridescence; // 0 = none, 1 = full thin-film interference effect
};

// Global material set by getDist, read by lighting functions
Material gMaterial = Material(vec3(0.5), 0.0, 0.5, vec3(0.0), 0.0);

// Compute iridescent color based on view angle (thin-film interference)
// viewAngle: dot(normal, viewDir), typically 0-1
// baseColor: the material's base albedo
// Returns: color shifted through spectrum based on angle
vec3 getIridescentColor(float viewAngle, vec3 baseColor) {
	// Thin-film interference creates rainbow colors based on angle
	// Using a spectral palette that shifts from blue -> green -> yellow -> red -> purple
	float hue = fract(viewAngle * 2.0 + 0.5);  // Shift through hues based on angle
	
	// Convert hue to RGB (simplified HSV to RGB)
	vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (hue + vec3(0.0, 0.33, 0.67)));
	
	// Blend with base color - iridescence is strongest at glancing angles
	float strength = pow(1.0 - viewAngle, 2.0);  // Stronger at edges
	return mix(baseColor, rainbow, strength * 0.8);
}

// Emissive light source info (centralized definition)
// Returns: position in xyz, radius in w
vec4 getEmissiveSource() {
	float glowY = 0.12 + sin(iTime * 1.2) * 0.03;
	vec3 pos = vec3(-0.15, glowY, -0.3);
	float radius = 0.05;
	return vec4(pos, radius);
}

// Returns: emission color in xyz, intensity in w
vec4 getEmissiveProperties() {
	float glowPulse = 0.8 + 0.2 * sin(iTime * 2.0);
	vec3 color = vec3(0.3, 0.9, 1.0);
	float intensity = 8.0 * glowPulse;
	return vec4(color, intensity);
}

// Create a basic dielectric (non-metal) material
Material createMaterial(vec3 albedo) {
	return Material(albedo, 0.0, 0.5, vec3(0.0), 0.0);
}

// Create a material with metallic/roughness control
Material createMaterial(vec3 albedo, float metallic, float roughness) {
	return Material(albedo, metallic, roughness, vec3(0.0), 0.0);
}

// Create a material with full control including emission
Material createMaterial(vec3 albedo, float metallic, float roughness, vec3 emission) {
	return Material(albedo, metallic, roughness, emission, 0.0);
}

// Create a material with full control including iridescence
Material createMaterial(vec3 albedo, float metallic, float roughness, vec3 emission, float iridescence) {
	return Material(albedo, metallic, roughness, emission, iridescence);
}

// Preset materials
Material matPlastic(vec3 color) {
	return Material(color, 0.0, 0.4, vec3(0.0), 0.0);
}

Material matMetal(vec3 color) {
	return Material(color, 1.0, 0.3, vec3(0.0), 0.0);
}

Material matRoughMetal(vec3 color) {
	return Material(color, 1.0, 0.7, vec3(0.0), 0.0);
}

Material matMirror() {
	return Material(vec3(0.9), 1.0, 0.0, vec3(0.0), 0.0);
}

Material matRubber(vec3 color) {
	return Material(color, 0.0, 0.9, vec3(0.0), 0.0);
}

// Glowing/emissive materials
// intensity: 1.0 = subtle glow, 3.0+ = bright glow
Material matGlow(vec3 color, float intensity) {
	return Material(color, 0.0, 1.0, color * intensity, 0.0);
}

Material matNeon(vec3 color) {
	return Material(color, 0.0, 0.8, color * 4.0, 0.0);
}

Material matLava(vec3 color) {
	return Material(color * 0.5, 0.0, 0.9, color * 3.0, 0.0);
}

Material matHotMetal(vec3 color) {
	return Material(color, 0.8, 0.4, color * 2.5, 0.0);
}

// Iridescent materials (color shifts with view angle)
// Soap bubble: transparent-ish with strong iridescence
Material matSoapBubble() {
	return Material(vec3(0.9, 0.95, 1.0), 0.0, 0.1, vec3(0.0), 1.0);
}

// Oil slick: dark base with rainbow sheen
Material matOilSlick() {
	return Material(vec3(0.05, 0.05, 0.1), 0.3, 0.2, vec3(0.0), 0.9);
}

// Beetle shell: green-ish metallic base with iridescence
Material matBeetleShell(vec3 baseColor) {
	return Material(baseColor, 0.6, 0.3, vec3(0.0), 0.7);
}

// Pearl: soft white with subtle iridescence
Material matPearl() {
	return Material(vec3(0.95, 0.93, 0.88), 0.0, 0.3, vec3(0.0), 0.4);
}

// Blend two materials (useful for smooth transitions)
Material mixMaterial(Material a, Material b, float t) {
	return Material(
		mix(a.albedo, b.albedo, t),
		mix(a.metallic, b.metallic, t),
		mix(a.roughness, b.roughness, t),
		mix(a.emission, b.emission, t),
		mix(a.iridescence, b.iridescence, t)
	);
}
