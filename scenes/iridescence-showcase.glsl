// Iridescence enhancement showcase
// Highlights thin-film, pearlescent, metallic, and transmissive variations

#ifndef SCENE_IRIDESCENCE_SHOWCASE_GLSL
#define SCENE_IRIDESCENCE_SHOWCASE_GLSL

// O(1): Scene-specific lighting for iridescence showcase
vec3 iridescenceShowcaseSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
	vec3 col = vec3(0.0);
	vec3 refRd = reflect(rd, normals);

#if RM_ENABLE_SPOTLIGHT
	// Cool key light sweeping across the iridescent row
	{
		vec3 spotPos = vec3(-0.9, 0.9, 0.7);
		vec3 spotTarget = vec3(-0.2, 0.2, 0.1);
		vec3 spotDir = normalize(spotTarget - spotPos);
		vec3 spotCol = vec3(0.65, 0.85, 1.0) * 0.9;
		col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, 0.35, 0.75);
	}
#endif

	// Warm rim light for edge highlights
	{
		vec3 rimPos = vec3(0.9, 0.5, -0.6);
		vec3 rimCol = vec3(1.0, 0.7, 0.4) * 0.75;
		col += getPointLight(hitPos, rimPos, normals, rd, refRd, rimCol, mate);
	}

	// Overhead fill to keep shadows readable
	{
		vec3 fillPos = vec3(0.0, 1.1, 0.2);
		vec3 fillCol = vec3(0.95, 0.95, 1.0) * 0.35;
		col += getPointLight(hitPos, fillPos, normals, rd, refRd, fillCol, mate);
	}

	return col;
}

// O(1): Iridescence enhancement showcase scene
vec4 iridescenceShowcaseScene(vec3 pos) {
	// Neutral dark floor to emphasize color shifts
	Material floorMat = createMaterial(vec3(0.09, 0.1, 0.12), 0.0, 0.85);
	SceneResult scene = sceneResult(fPlane(pos, vec3(0.0, 1.0, 0.0), 0.0), floorMat);

	float y = 0.18;
	float spacing = 0.38;
	float bounce = sin(iTime * 1.2) * 0.015;

	// 1) Thin-film bubble (transmissive)
	Material bubbleMat = Material(
		vec3(0.85, 0.92, 1.0),
		0.0, 0.03,
		vec3(0.0),
		1.0, 0.0, vec3(1.0),
		0.95, 1.33, 0.0
	);
	vec3 bubblePos = pos - vec3(-spacing * 2.0, y + bounce, 0.1);
	SceneResult bubble = sceneResult(fSphere(bubblePos, 0.13), bubbleMat);
	scene = sceneMin(scene, bubble);

	// 2) Oil slick puddle (thin torus close to ground)
	Material slickMat = createMaterial(vec3(0.05, 0.06, 0.09), 0.2, 0.18, vec3(0.0), 0.95);
	vec3 slickPos = pos - vec3(-spacing * 0.7, 0.05, -0.1);
	float slick = fTorus(slickPos, 0.02, 0.18);
	scene = sceneMin(scene, sceneResult(slick, slickMat));

	// 3) Pearlescent shell (rougher, softer iridescence)
	Material pearlMat = createMaterial(vec3(0.92, 0.9, 0.86), 0.0, 0.55, vec3(0.0), 0.55);
	vec3 pearlPos = pos - vec3(spacing * 0.2, y + bounce * 0.6, 0.0);
	SceneResult pearl = sceneResult(fSphere(pearlPos, 0.13), pearlMat);
	scene = sceneMin(scene, pearl);

	// 4) Holographic foil slab (metallic, glossy)
	Material holoMat = createMaterial(vec3(0.2, 0.25, 0.35), 0.9, 0.12, vec3(0.0), 0.85);
	vec3 holoPos = pos - vec3(spacing * 1.2, 0.12 + bounce * 0.4, 0.05);
	mat3 holoRot = getRotationMatrix(normalize(vec3(0.2, 1.0, 0.3)), 0.6);
	vec3 holoP = holoRot * holoPos;
	SceneResult holo = sceneResult(fBox(holoP, vec3(0.18, 0.03, 0.12)), holoMat);
	scene = sceneMin(scene, holo);

	// 5) Beetle shell capsule (metallic iridescence)
	Material beetleMat = createMaterial(vec3(0.08, 0.2, 0.18), 0.7, 0.25, vec3(0.0), 0.8);
	vec3 beetlePos = pos - vec3(spacing * 2.1, y + bounce * 0.9, -0.05);
	vec3 a = vec3(-0.08, 0.0, 0.0);
	vec3 b = vec3(0.08, 0.0, 0.0);
	SceneResult beetle = sceneResult(fCapsule(beetlePos, a, b, 0.09), beetleMat);
	scene = sceneMin(scene, beetle);

	// 6) Dual-layer blend (pearlescent + metallic)
	float blendK = 0.06;
	vec3 blendPos = pos - vec3(0.0, y + bounce * 0.7, 0.45);
	SceneResult blendA = sceneResult(fSphere(blendPos, 0.11), pearlMat);
	SceneResult blendB = sceneResult(fSphere(blendPos + vec3(0.12, 0.03, 0.03), 0.11), holoMat);
	SceneResult blend = sceneSmin(blendA, blendB, blendK);
	scene = sceneMin(scene, blend);

	gMaterial = scene.mat;
	return vec4(scene.mat.albedo, scene.dist);
}

// O(1): Scene-specific background
vec3 iridescenceShowcaseBackground(vec2 skyUV, vec3 rd, vec3 ro) {
	vec3 base = rmSkyBase(rd, ro);

	// Soft horizon glow with subtle spectral banding
	float horizon = smoothstep(0.42, 0.55, skyUV.y);
	float band = sin((skyUV.x * 3.0 + skyUV.y * 1.7) * 6.28318);
	vec3 spectrum = 0.5 + 0.5 * cos(vec3(0.0, 2.1, 4.2) + band);
	base = mix(base, spectrum, horizon * 0.25);

	// Gentle vignette
	float v = smoothstep(0.0, 0.2, skyUV.y) * smoothstep(1.0, 0.7, skyUV.y);
	base *= mix(0.75, 1.0, v);

	return base;
}

#endif
