// Post-processing pipeline: lens flare, fog, tone mapping, gamma correction
// col: color to process (modified in place)
// rd: ray direction
// ro: ray origin
// bgCol: background color for fog blending
// dist: distance to the object for fog calculation
void getPostProcessing(inout vec3 col, vec3 rd, vec3 ro, vec3 bgCol, float dist){
	// Lens flare
	col += getLensFlare(rd, ro, lightPos, vec3(0.9, 0.2, 8.0), 10.0) * 0.5;

	// Distance fog
	col = distanceFog(col, bgCol, dist);

	// Tone mapping and gamma correction
	col = toneMapping(col);
	col = gammaCorrection(col);
}