// Material definitions and utilities

struct Material {
	vec3 albedo;        // Base color
	float metallic;     // 0 = dielectric (plastic, wood), 1 = metal (gold, iron)
	float roughness;    // 0 = mirror smooth, 1 = fully diffuse
	vec3 emission;      // Self-illumination color (black = no glow)
	float iridescence;  // 0 = none, 1 = full thin-film interference effect
	float subsurface;   // 0 = none, 1 = full subsurface scattering
	vec3 subsurfaceCol; // Color of light transmitted through the material
	float transmission; // 0 = opaque, 1 = fully transmissive
	float ior;          // Index of refraction (1.0 = air)
	float toonSteps;    // 0 = disable, >0 = toon band count
};

// Global material set by getDist, read by lighting functions
Material gMaterial = Material(vec3(0.5), 0.0, 0.5, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);

// Compute iridescent color based on view angle (thin-film interference)
// viewAngle: dot(normal, viewDir), typically 0-1
// baseColor: the material's base albedo
// Returns: color shifted through spectrum based on angle
vec3 getIridescentColor(float viewAngle, vec3 baseColor) {
	float ndv = clamp(viewAngle, 0.0, 1.0);
	float edge = pow(1.0 - ndv, 1.35);
	
	float roughness = clamp(gMaterial.roughness, 0.0, 1.0);
	float metallic = clamp(gMaterial.metallic, 0.0, 1.0);
	float transmission = clamp(gMaterial.transmission, 0.0, 1.0);
	
	// Approximate thin-film interference with three wavelength bands.
	float luma = clamp(dot(baseColor, vec3(0.3333)), 0.0, 1.0);
	float thickness = mix(240.0, 980.0, luma);
	thickness *= mix(0.9, 1.15, metallic);
	thickness *= 1.0 + 0.18 * sin((ndv * 1.7 + luma * 0.9) * 6.28318);
	
	vec3 lambda = vec3(680.0, 530.0, 440.0);
	vec3 phase = (6.28318 * thickness) / lambda;
	
	vec3 interference = 0.5 + 0.5 * cos(phase + vec3(0.0, 2.1, 4.2) + ndv * 2.4);
	vec3 pearlescent = 0.5 + 0.5 * cos((phase * 0.65) + vec3(1.0, 3.0, 5.1) - ndv * 1.4);
	vec3 film = mix(interference, pearlescent, 0.35 + 0.35 * metallic);
	
	float filmStrength = edge * mix(0.25, 1.0, 1.0 - roughness);
	filmStrength = mix(filmStrength, filmStrength * 1.1, transmission);
	
	return mix(baseColor, film, filmStrength);
}

// Number of emissive light sources per scene
// Each scene defines its own emissive configuration
#if RM_ACTIVE_SCENE == SCENE_SHOWCASE
#define NUM_EMISSIVES 6
#elif RM_ACTIVE_SCENE == SCENE_CAUSTICS
#define NUM_EMISSIVES 0  // Caustics scene has no emissive objects
#elif RM_ACTIVE_SCENE == SCENE_ENV_MAP
#define NUM_EMISSIVES 0  // Env map scene uses explicit lights
#elif RM_ACTIVE_SCENE == SCENE_NIGHT_LIGHTS
#define NUM_EMISSIVES 5
#else
#define NUM_EMISSIVES 0
#endif

// Emissive light source info (scene-specific definitions)
// index: 0 to NUM_EMISSIVES-1
// Returns: position in xyz, radius in w
vec4 getEmissiveSource(int index) {
#if RM_ACTIVE_SCENE == SCENE_SHOWCASE
	// Showcase scene: emissives inside SSS spheres
	float sssSpacing = 0.3;
#if RM_ENABLE_SSS
	float sssY = 0.42 + sin(iTime * 0.6) * 0.01;
	float sssZ = 0.65;
#else
	float sssY = 0.32;
	float sssZ = 0.45;
#endif
	
	if (index == 0) {
		// Red - inside SKIN sphere (blood glow)
		return vec4(-sssSpacing * 0.5, sssY + 0.01, sssZ - 0.05, 0.03);
	} else if (index == 1) {
		// Green - STANDALONE (keep original position)
		float rowY = 0.22 + sin(iTime * 1.2 + 1.5) * 0.02;
		return vec4(0.0, rowY + 0.21, -0.9, 0.05);
	} else if (index == 2) {
		// Blue/Cyan - inside MARBLE sphere (cool glow)
		return vec4(sssSpacing * 1.5, sssY + 0.03, sssZ - 0.15, 0.03);
	} else if (index == 3) {
		// Warm candle - inside WAX sphere
		return vec4(-sssSpacing * 1.5, sssY, sssZ, 0.03);
	} else if (index == 4) {
		// Green/teal - inside JADE sphere (mystical glow)
		return vec4(sssSpacing * 0.5, sssY + 0.02, sssZ - 0.1, 0.03);
	} else {
		// Spotlight position marker (dim reference)
		return vec4(0.8, 0.5, -0.3, 0.02);
	}
#elif RM_ACTIVE_SCENE == SCENE_NIGHT_LIGHTS
	// Night lights scene: ground-level lanterns and a hero orb
	if (index == 0) {
		return vec4(-0.75, 0.18, 0.4, 0.06);
	} else if (index == 1) {
		return vec4(-0.2, 0.22, 0.1, 0.05);
	} else if (index == 2) {
		return vec4(0.35, 0.2, 0.35, 0.05);
	} else if (index == 3) {
		return vec4(0.8, 0.18, 0.0, 0.06);
	} else {
		return vec4(0.0, 0.38, -0.45, 0.08);
	}
#else
	// Default: no emissives
	return vec4(0.0, -100.0, 0.0, 0.0);
#endif
}

// Returns: emission color in xyz, intensity in w
// index: 0 to NUM_EMISSIVES-1
vec4 getEmissiveProperties(int index) {
#if RM_ACTIVE_SCENE == SCENE_SHOWCASE
	// Showcase scene: glowing emissives inside SSS materials
	float seed = fract(sin(float(index) * 12.9898) * 43758.5453);
	float phase = seed * 6.28318 * RM_EMISSIVE_FLICKER_STAGGER;
	float glowPulse = 0.8 + 0.2 * sin(iTime * 2.0 + float(index) * 2.0 + phase * 0.6);
	float flicker = 0.9 + 0.1 * sin(iTime * 8.0 + phase) * sin(iTime * 12.0 + 1.0 + phase * 1.3);
	float interiorIntensity = 2.0 * flicker;  // Subtle glow for SSS materials
	
	if (index == 0) {
		// Red - inside skin (blood/flesh glow)
		return vec4(1.0, 0.15, 0.1, interiorIntensity);
	} else if (index == 1) {
		// Green - standalone
		return vec4(0.2, 1.0, 0.3, 1.0 * glowPulse);
	} else if (index == 2) {
		// Blue/Cyan - inside marble (cool ethereal)
		return vec4(0.4, 0.7, 1.0, interiorIntensity);
	} else if (index == 3) {
		// Warm candle - inside wax
		return vec4(1.0, 0.6, 0.2, interiorIntensity);
	} else if (index == 4) {
		// Teal/green - inside jade (mystical)
		return vec4(0.2, 1.0, 0.6, interiorIntensity);
	} else {
		// Spotlight marker (dim)
		return vec4(1.0, 0.95, 0.9, 0.25);
	}
#elif RM_ACTIVE_SCENE == SCENE_NIGHT_LIGHTS
	// Night lights scene: lantern flicker with warm/cool mix
	float seed = fract(sin(float(index) * 78.233) * 43758.5453);
	float phase = seed * 6.28318 * RM_EMISSIVE_FLICKER_STAGGER;
	float baseFlicker = 0.85 + 0.15 * sin(iTime * 6.5 + phase) * sin(iTime * 9.0 + 1.7 + phase * 1.2);
	float pulse = 0.9 + 0.1 * sin(iTime * 1.4 + phase * 0.8);
	float intensity = baseFlicker * pulse * 1.6;

	if (index == 0) {
		return vec4(1.0, 0.6, 0.25, intensity);
	} else if (index == 1) {
		return vec4(0.9, 0.8, 0.3, intensity * 0.9);
	} else if (index == 2) {
		return vec4(0.2, 0.7, 1.0, intensity * 0.75);
	} else if (index == 3) {
		return vec4(1.0, 0.35, 0.2, intensity * 0.85);
	} else {
		return vec4(0.6, 0.85, 1.0, intensity * 0.65);
	}
#else
	// Default: no emission
	return vec4(0.0, 0.0, 0.0, 0.0);
#endif
}

// Create a basic dielectric (non-metal) material
Material createMaterial(vec3 albedo) {
	return Material(albedo, 0.0, 0.5, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

// Create a material with metallic/roughness control
Material createMaterial(vec3 albedo, float metallic, float roughness) {
	return Material(albedo, metallic, roughness, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

// Create a material with full control including emission
Material createMaterial(vec3 albedo, float metallic, float roughness, vec3 emission) {
	return Material(albedo, metallic, roughness, emission, 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

// Create a material with full control including iridescence
Material createMaterial(vec3 albedo, float metallic, float roughness, vec3 emission, float iridescence) {
	return Material(albedo, metallic, roughness, emission, iridescence, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

// Create a material with full control including subsurface scattering
Material createMaterial(vec3 albedo, float metallic, float roughness, vec3 emission, float iridescence, float subsurface, vec3 subsurfaceCol) {
	return Material(albedo, metallic, roughness, emission, iridescence, subsurface, subsurfaceCol, 0.0, 1.0, 0.0);
}

// Preset materials
Material matPlastic(vec3 color) {
	return Material(color, 0.0, 0.4, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

Material matMetal(vec3 color) {
	return Material(color, 1.0, 0.3, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

// Polished gold - very shiny with warm reflections
Material matGold() {
	return Material(vec3(1.0, 0.76, 0.33), 1.0, 0.05, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

Material matRoughMetal(vec3 color) {
	return Material(color, 1.0, 0.7, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

Material matMirror() {
	return Material(vec3(0.9), 1.0, 0.0, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

Material matRubber(vec3 color) {
	return Material(color, 0.0, 0.9, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

// Glowing/emissive materials
Material matGlow(vec3 color, float intensity) {
	return Material(color, 0.0, 1.0, color * intensity, 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

Material matNeon(vec3 color) {
	return Material(color, 0.0, 0.8, color * 4.0, 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

Material matLava(vec3 color) {
	return Material(color * 0.5, 0.0, 0.9, color * 3.0, 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

Material matHotMetal(vec3 color) {
	return Material(color, 0.8, 0.4, color * 2.5, 0.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

// Iridescent materials (color shifts with view angle)
Material matSoapBubble() {
	return Material(vec3(0.9, 0.95, 1.0), 0.0, 0.1, vec3(0.0), 1.0, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

Material matOilSlick() {
	return Material(vec3(0.05, 0.05, 0.1), 0.3, 0.2, vec3(0.0), 0.9, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

Material matBeetleShell(vec3 baseColor) {
	return Material(baseColor, 0.6, 0.3, vec3(0.0), 0.7, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

Material matPearl() {
	return Material(vec3(0.95, 0.93, 0.88), 0.0, 0.3, vec3(0.0), 0.4, 0.0, vec3(1.0), 0.0, 1.0, 0.0);
}

// Subsurface scattering materials (light penetrates and scatters inside)
// Wax: warm translucent material (orange/red glow when backlit)
Material matWax(vec3 color) {
	return Material(color, 0.0, 0.6, vec3(0.0), 0.0, 1.0, vec3(1.0, 0.5, 0.2), 0.0, 1.0, 0.0);
}

// Skin: realistic flesh tones with strong red SSS
Material matSkin(vec3 color) {
	return Material(color, 0.0, 0.5, vec3(0.0), 0.0, 0.9, vec3(1.0, 0.2, 0.1), 0.0, 1.0, 0.0);
}

// Jade: green stone with bright green internal glow
Material matJade(vec3 color) {
	return Material(color, 0.0, 0.3, vec3(0.0), 0.0, 1.0, vec3(0.3, 1.0, 0.4), 0.0, 1.0, 0.0);
}

// Marble: white stone with warm translucency
Material matMarble() {
	return Material(vec3(0.95, 0.93, 0.9), 0.0, 0.2, vec3(0.0), 0.0, 0.7, vec3(1.0, 0.9, 0.7), 0.0, 1.0, 0.0);
}

// Gummy bear / gelatin-like SSS material.
// Saturated subsurface color with a smoother surface to catch highlights.
Material matGummyBear(vec3 color) {
	vec3 base = clamp(color, 0.0, 1.0);
	// Candy gels tend to scatter red/orange light much more strongly.
	vec3 sssCol = clamp(base * vec3(1.35, 0.55, 0.45) + vec3(0.08, 0.01, 0.00), 0.0, 1.0);
	return Material(
		mix(base, vec3(1.0), 0.1), // slightly lifted albedo for candy look
		0.0,
		0.10,                      // glossier surface reads "gel"
		vec3(0.0),
		0.0,
		2.4,                       // strong SSS (boosted)
		sssCol,
		0.0,                       // keep opaque in this template's model (SSS does the "gummy" feel)
		1.0,
		0.0
	);
}

// O(1): Transparent glass material setup.
// Warm amber tint like antique bottle glass
Material matGlass() {
	return Material(vec3(0.95, 0.75, 0.5), 0.0, 0.12, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.92, 1.52, 0.0);
}

// O(1): Transparent water/liquid material setup.
// Deep aqua-cyan like tropical ocean
Material matWater() {
	return Material(vec3(0.3, 0.85, 0.95), 0.0, 0.02, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.98, 1.33, 0.0);
}

// O(1): Transparent crystal/gem material setup.
// Rich amethyst purple with high IOR for strong refraction
Material matCrystal() {
	return Material(vec3(0.7, 0.3, 0.9), 0.0, 0.01, vec3(0.0), 0.15, 0.0, vec3(1.0), 0.96, 2.0, 0.0);
}

// O(1): Toon material setup (steps control banding).
// steps: number of discrete lighting bands
Material matToon(vec3 color, float steps) {
	return Material(color, 0.0, 0.6, vec3(0.0), 0.0, 0.0, vec3(1.0), 0.0, 1.0, steps);
}

// Blend two materials (useful for smooth transitions)
Material mixMaterial(Material a, Material b, float t) {
	return Material(
		mix(a.albedo, b.albedo, t),
		mix(a.metallic, b.metallic, t),
		mix(a.roughness, b.roughness, t),
		mix(a.emission, b.emission, t),
		mix(a.iridescence, b.iridescence, t),
		mix(a.subsurface, b.subsurface, t),
		mix(a.subsurfaceCol, b.subsurfaceCol, t),
		mix(a.transmission, b.transmission, t),
		mix(a.ior, b.ior, t),
		mix(a.toonSteps, b.toonSteps, t)
	);
}
