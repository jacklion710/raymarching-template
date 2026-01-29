// Material definitions and utilities

struct Material {
	vec3 albedo;      // Base color
	float metallic;   // 0 = dielectric (plastic, wood), 1 = metal (gold, iron)
	float roughness;  // 0 = mirror smooth, 1 = fully diffuse
	vec3 emission;    // Self-illumination color (black = no glow)
};

// Global material set by getDist, read by lighting functions
Material gMaterial = Material(vec3(0.5), 0.0, 0.5, vec3(0.0));

// Create a basic dielectric (non-metal) material
Material createMaterial(vec3 albedo) {
	return Material(albedo, 0.0, 0.5, vec3(0.0));
}

// Create a material with metallic/roughness control
Material createMaterial(vec3 albedo, float metallic, float roughness) {
	return Material(albedo, metallic, roughness, vec3(0.0));
}

// Create a material with full control including emission
Material createMaterial(vec3 albedo, float metallic, float roughness, vec3 emission) {
	return Material(albedo, metallic, roughness, emission);
}

// Preset materials
Material matPlastic(vec3 color) {
	return Material(color, 0.0, 0.4, vec3(0.0));
}

Material matMetal(vec3 color) {
	return Material(color, 1.0, 0.3, vec3(0.0));
}

Material matRoughMetal(vec3 color) {
	return Material(color, 1.0, 0.7, vec3(0.0));
}

Material matMirror() {
	return Material(vec3(0.9), 1.0, 0.0, vec3(0.0));
}

Material matRubber(vec3 color) {
	return Material(color, 0.0, 0.9, vec3(0.0));
}

// Glowing/emissive materials
// intensity: 1.0 = subtle glow, 3.0+ = bright glow
Material matGlow(vec3 color, float intensity) {
	return Material(color, 0.0, 1.0, color * intensity);
}

Material matNeon(vec3 color) {
	return Material(color, 0.0, 0.8, color * 4.0);  // Bright neon
}

Material matLava(vec3 color) {
	return Material(color * 0.5, 0.0, 0.9, color * 3.0);
}

Material matHotMetal(vec3 color) {
	return Material(color, 0.8, 0.4, color * 2.5);  // Glowing hot metal
}

// Blend two materials (useful for smooth transitions)
Material mixMaterial(Material a, Material b, float t) {
	return Material(
		mix(a.albedo, b.albedo, t),
		mix(a.metallic, b.metallic, t),
		mix(a.roughness, b.roughness, t),
		mix(a.emission, b.emission, t)
	);
}
