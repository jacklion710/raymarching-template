// Material definitions and utilities

struct Material {
	vec3 albedo;      // Base color
	float metallic;   // 0 = dielectric (plastic, wood), 1 = metal (gold, iron)
	float roughness;  // 0 = mirror smooth, 1 = fully diffuse
};

// Global material set by getDist, read by lighting functions
Material gMaterial = Material(vec3(0.5), 0.0, 0.5);

// Create a basic dielectric (non-metal) material
Material createMaterial(vec3 albedo) {
	return Material(albedo, 0.0, 0.5);
}

// Create a material with full control
Material createMaterial(vec3 albedo, float metallic, float roughness) {
	return Material(albedo, metallic, roughness);
}

// Preset materials
Material matPlastic(vec3 color) {
	return Material(color, 0.0, 0.4);
}

Material matMetal(vec3 color) {
	return Material(color, 1.0, 0.3);
}

Material matRoughMetal(vec3 color) {
	return Material(color, 1.0, 0.7);
}

Material matMirror() {
	return Material(vec3(0.9), 1.0, 0.0);
}

Material matRubber(vec3 color) {
	return Material(color, 0.0, 0.9);
}

// Blend two materials (useful for smooth transitions)
Material mixMaterial(Material a, Material b, float t) {
	return Material(
		mix(a.albedo, b.albedo, t),
		mix(a.metallic, b.metallic, t),
		mix(a.roughness, b.roughness, t)
	);
}
