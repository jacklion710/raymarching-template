// Calculate glow aura from emissive objects
// Returns additive glow color based on ray proximity to emissive source
vec3 getEmissiveGlow(vec3 ro, vec3 rd, float sceneDepth) {
	// Emissive sphere position (must match scene)
	float glowY = 0.12 + sin(iTime * 1.2) * 0.03;
	vec3 emissivePos = vec3(-0.15, glowY, -0.3);
	float glowPulse = 0.8 + 0.2 * sin(iTime * 2.0);
	vec3 emissiveCol = vec3(0.3, 0.9, 1.0) * 3.0 * glowPulse;
	float emissiveRadius = 0.05;
	
	// Find closest point on ray to emissive center
	vec3 toEmissive = emissivePos - ro;
	float t = max(dot(toEmissive, rd), 0.0);  // Project onto ray
	t = min(t, sceneDepth);  // Don't glow behind solid objects
	
	vec3 closestPoint = ro + rd * t;
	float distToEmissive = length(closestPoint - emissivePos);
	
	// Soft glow falloff - extends well beyond the object
	float glowRadius = emissiveRadius * 6.0;  // Glow extends 6x the object size
	float glow = 1.0 - smoothstep(0.0, glowRadius, distToEmissive);
	glow = glow * glow;  // Quadratic falloff for softer edge
	
	return emissiveCol * glow * 0.4;
}

// Post-processing pipeline: lens flare, fog, tone mapping, gamma correction
// col: color to process (modified in place)
// rd: ray direction
// ro: ray origin
// bgCol: background color for fog blending
// dist: distance to the object for fog calculation
void getPostProcessing(inout vec3 col, vec3 rd, vec3 ro, vec3 bgCol, float dist){
	// Emissive glow aura (before fog so it's affected by atmosphere)
	col += getEmissiveGlow(ro, rd, dist);
	
	// Lens flare
	col += getLensFlare(rd, ro, lightPos, vec3(0.9, 0.2, 8.0), 10.0) * 0.5;

	// Distance fog
	col = distanceFog(col, bgCol, dist);

	// Tone mapping and gamma correction
	col = toneMapping(col);
	col = gammaCorrection(col);
}