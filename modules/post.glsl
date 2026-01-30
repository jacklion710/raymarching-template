// Calculate glow aura from all emissive objects
// Loops through centralized emissive definitions
vec3 getEmissiveGlow(vec3 ro, vec3 rd, float sceneDepth) {
	vec3 totalGlow = vec3(0.0);
	
	for (int i = 0; i < NUM_EMISSIVES; i++) {
		vec4 source = getEmissiveSource(i);
		vec4 props = getEmissiveProperties(i);
		
		vec3 emissivePos = source.xyz;
		float emissiveRadius = source.w;
		vec3 emissiveCol = props.xyz * props.w * 0.15;  // Reduced glow
		
		// Find closest point on ray to emissive center
		vec3 toEmissive = emissivePos - ro;
		float t = max(dot(toEmissive, rd), 0.0);
		t = min(t, sceneDepth);
		
		vec3 closestPoint = ro + rd * t;
		float distToEmissive = length(closestPoint - emissivePos);
		
		// Soft glow falloff
		float glowRadius = emissiveRadius * 4.0;  // Tighter glow radius
		float glow = 1.0 - smoothstep(0.0, glowRadius, distToEmissive);
		glow = glow * glow;
		
		totalGlow += emissiveCol * glow * 0.2;  // Reduced multiplier
	}
	
	return totalGlow;
}

// Post-processing pipeline with modular effects.
// Comment/uncomment individual effects to audition them.
// col: color to process (modified in place)
// rd: ray direction
// ro: ray origin
// bgCol: background color for fog blending
// dist: distance to the object for fog calculation
// uv: normalized screen coordinates (0 to 1)
void getPostProcessing(inout vec3 col, vec3 rd, vec3 ro, vec3 bgCol, float dist, vec2 uv){
	
	// ===== PRE-TONEMAPPING EFFECTS (linear space) =====
	
	// Emissive glow aura
	col += getEmissiveGlow(ro, rd, dist);
	
	// Lens flare
	col += getLensFlare(rd, ro, lightPos, vec3(1.0, 0.75, 0.7), 10.0) * 0.5;

	// Distance fog
	col = distanceFog(col, bgCol, dist);
	
	// Exposure adjustment (before tone mapping)
	// col = exposure(col, 0.99);
	
	// ===== TONE MAPPING =====
	col = toneMapping(col);
	
	// ===== POST-TONEMAPPING EFFECTS (display space) =====
	
	// Color grading - uncomment to enable
	col = contrast(col, 1.1);                    // >1.0 = more contrast
	col = saturation(col, 1.15);                 // >1.0 = more saturated
	col = brightness(col, 0.02);                  // +/- brightness shift
	col = colorTemperature(col, 0.5);            // -1=cool, 0=neutral, 1=warm
	// col = hueShift(col, 0.0);                    // radians rotation
	
	// Split toning - adds color character
	col = splitToning(col, vec3(0.9, 0.95, 1.1), vec3(1.1, 1.0, 0.9), 0.75);
	
	// Lift/Gamma/Gain presets - uncomment ONE to try
	col = liftGammaGain(col, vec3(0.0), vec3(1.0), vec3(1.0));  // Neutral (no change)
	
	// TEAL AND ORANGE (blockbuster movie look - cool shadows, warm highlights)
	// col = liftGammaGain(col, vec3(-0.02, 0.01, 0.04), vec3(0.95, 1.0, 1.05), vec3(1.1, 0.98, 0.85));
	
	// COOL MOODY (blue shadows, slightly desaturated feel)
	// col = liftGammaGain(col, vec3(0.0, 0.02, 0.05), vec3(0.98, 0.98, 1.02), vec3(0.95, 0.97, 1.0));
	
	// GOLDEN HOUR (warm orange glow throughout)
	// col = liftGammaGain(col, vec3(0.02, 0.01, -0.02), vec3(1.02, 1.0, 0.95), vec3(1.1, 1.0, 0.88));
	
	// HIGH CONTRAST CINEMATIC (punchy blacks, bright whites)
	// col = liftGammaGain(col, vec3(-0.03), vec3(0.9), vec3(1.15));
	
	// FADED VINTAGE (lifted blacks, muted highlights)
	// col = liftGammaGain(col, vec3(0.05, 0.04, 0.06), vec3(1.05), vec3(0.95, 0.93, 0.9));
	
	// MATRIX GREEN (green tint in shadows and midtones)
	// col = liftGammaGain(col, vec3(-0.02, 0.03, -0.02), vec3(0.95, 1.05, 0.95), vec3(0.9, 1.0, 0.9));
	
	// Local contrast / sharpening approximation
	col = localContrast(col, 0.7);  // 0.3 = subtle, 0.6 = strong
	
	// Chromatic aberration - RGB fringing at edges (lens effect)
	// col = chromaticAberration(col, uv, 0.04);  // 0.005 = subtle, 0.03 = strong
	
	// Vignette - darkens edges for cinematic focus
	vec2 vigUV = uv - 0.5;  // Center-relative coords
	col = vignette(col, vigUV, 0.4, 0.7);
	
	// Film grain - organic texture (subtle)
	col = filmGrain(col, uv, iTime, 0.03);
	
	// ===== FINAL OUTPUT =====
	
	// Dithering - reduces banding (apply before gamma)
	col = dither(col, uv * 1000.0, 8.0);
	
	// Gamma correction (always last)
	col = gammaCorrection(col);
}