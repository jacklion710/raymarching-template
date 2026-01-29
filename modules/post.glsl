// Calculate glow aura from emissive objects
// Uses centralized emissive definition from getEmissiveSource/getEmissiveProperties
vec3 getEmissiveGlow(vec3 ro, vec3 rd, float sceneDepth) {
	// Get emissive source info (centralized)
	vec4 source = getEmissiveSource();
	vec4 props = getEmissiveProperties();
	
	vec3 emissivePos = source.xyz;
	float emissiveRadius = source.w;
	vec3 emissiveCol = props.xyz * props.w * 0.4;  // Color * intensity * glow factor
	
	// Find closest point on ray to emissive center
	vec3 toEmissive = emissivePos - ro;
	float t = max(dot(toEmissive, rd), 0.0);
	t = min(t, sceneDepth);
	
	vec3 closestPoint = ro + rd * t;
	float distToEmissive = length(closestPoint - emissivePos);
	
	// Soft glow falloff - extends well beyond the object
	float glowRadius = emissiveRadius * 6.0;
	float glow = 1.0 - smoothstep(0.0, glowRadius, distToEmissive);
	glow = glow * glow;
	
	return emissiveCol * glow * 0.3;
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