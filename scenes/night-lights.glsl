// Night lights showcase scene with moonlit atmosphere

#ifndef SCENE_NIGHT_LIGHTS_GLSL
#define SCENE_NIGHT_LIGHTS_GLSL

// O(1): Scene-specific lighting for night lights showcase
vec3 nightLightsSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
	vec3 col = vec3(0.0);
	vec3 refRd = reflect(rd, normals);

	// Flicker helpers (desynced)
	float t = iTime;
	float flickerA = 0.85 + 0.15 * sin(t * 6.2) * sin(t * 9.3 + 1.4);
	float flickerB = 0.88 + 0.12 * sin(t * 5.7 + 2.1) * sin(t * 11.1 + 0.6);
	float flickerC = 0.9 + 0.1 * sin(t * 7.1 + 3.2) * sin(t * 8.6 + 1.1);

#if RM_ENABLE_SPOTLIGHT
	// Moonlit cone wash (cool, soft)
	{
		vec3 spotPos = vec3(-0.6, 1.2, 0.6);
		vec3 spotTarget = vec3(0.0, 0.1, 0.0);
		vec3 spotDir = normalize(spotTarget - spotPos);
		vec3 spotCol = vec3(0.55, 0.75, 1.0) * 0.55;
		col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, 0.55, 1.05);
	}

	// Warm lantern cone (flickering)
	{
		vec3 spotPos = vec3(0.65, 0.6, 0.15);
		vec3 spotTarget = vec3(0.65, 0.12, 0.15);
		vec3 spotDir = normalize(spotTarget - spotPos);
		vec3 spotCol = vec3(1.0, 0.65, 0.3) * (0.7 * flickerA);
		col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, 0.35, 0.8);
	}
#endif

	// Flickering point lights (warm + cool)
	{
		vec3 pointPos = vec3(-0.55, 0.32, 0.45);
		vec3 pointCol = vec3(1.0, 0.55, 0.25) * (0.7 * flickerB);
		col += getPointLight(hitPos, pointPos, normals, rd, refRd, pointCol, mate);
	}
	{
		vec3 pointPos = vec3(0.25, 0.28, 0.4);
		vec3 pointCol = vec3(0.3, 0.7, 1.0) * (0.55 * flickerC);
		col += getPointLight(hitPos, pointPos, normals, rd, refRd, pointCol, mate);
	}

	return col;
}

// O(1): Night lights showcase scene
vec4 nightLightsScene(vec3 pos) {
	// Dark slate floor for reflections
	Material floorMat = createMaterial(vec3(0.08, 0.09, 0.11), 0.0, 0.55);
	SceneResult scene = sceneResult(fPlane(pos, vec3(0.0, 1.0, 0.0), 0.0), floorMat);

	float baseY = 0.18;
	float spacing = 0.38;
	float sway = sin(iTime * 1.0) * 0.01;

	// Hero moon plinth
	vec3 plinthPos = pos - vec3(0.0, 0.08, -0.5);
	SceneResult plinth = sceneResult(fBox(plinthPos, vec3(0.32, 0.08, 0.2)), createMaterial(vec3(0.18, 0.2, 0.25), 0.0, 0.7));
	scene = sceneMin(scene, plinth);

	// Lantern housings
	vec3 lantern1 = pos - vec3(-spacing * 2.0, baseY + sway, 0.35);
	SceneResult lampA = sceneResult(fBox(lantern1, vec3(0.12, 0.18, 0.12)), createMaterial(vec3(0.12, 0.14, 0.16), 0.0, 0.7));
	scene = sceneMin(scene, lampA);

	vec3 lantern2 = pos - vec3(-spacing * 0.7, baseY + sway * 0.6, 0.05);
	SceneResult lampB = sceneResult(fBox(lantern2, vec3(0.11, 0.16, 0.11)), createMaterial(vec3(0.14, 0.16, 0.2), 0.0, 0.6));
	scene = sceneMin(scene, lampB);

	vec3 lantern3 = pos - vec3(spacing * 0.8, baseY + sway * 0.8, 0.3);
	SceneResult lampC = sceneResult(fBox(lantern3, vec3(0.11, 0.17, 0.11)), createMaterial(vec3(0.1, 0.12, 0.15), 0.0, 0.65));
	scene = sceneMin(scene, lampC);

	vec3 lantern4 = pos - vec3(spacing * 2.0, baseY + sway * 0.4, 0.0);
	SceneResult lampD = sceneResult(fBox(lantern4, vec3(0.12, 0.18, 0.12)), createMaterial(vec3(0.13, 0.12, 0.15), 0.0, 0.7));
	scene = sceneMin(scene, lampD);

	// Hero orb (metal + glow)
	vec3 orbPos = pos - vec3(0.0, 0.35 + sway, -0.45);
	SceneResult orb = sceneResult(
		fSphere(orbPos, 0.12),
		createMaterial(vec3(0.2, 0.35, 0.6), 0.4, 0.18, vec3(0.0), 0.45)
	);
	scene = sceneMin(scene, orb);

	// Emissive inserts (use centralized emissives)
#if RM_ENABLE_EMISSIVE
	for (int i = 0; i < NUM_EMISSIVES; i++) {
		vec4 source = getEmissiveSource(i);
		vec4 props = getEmissiveProperties(i);
		vec3 glowPos = pos - source.xyz;
		SceneResult glowSphere = sceneResult(
			fSphere(glowPos, source.w),
			matGlow(props.xyz, props.w)
		);
		scene = sceneMin(scene, glowSphere);
	}
#endif

	gMaterial = scene.mat;
	return vec4(scene.mat.albedo, scene.dist);
}

// O(1): Scene-specific background with moon + stars
vec3 nightLightsBackground(vec2 skyUV, vec3 rd, vec3 ro) {
	vec3 base = rmSkyBase(rd, ro);
	base *= vec3(0.12, 0.16, 0.25);

	// Subtle vertical gradient
	base = mix(base * 0.6, base, smoothstep(0.1, 0.8, skyUV.y));

	// Moon disc
	vec2 moonUV = skyUV - vec2(0.72, 0.78);
	float moon = smoothstep(0.12, 0.11, length(moonUV));
	float glow = smoothstep(0.3, 0.12, length(moonUV));
	vec3 moonCol = vec3(0.9, 0.95, 1.0);
	base = mix(base, moonCol, moon);
	base += moonCol * glow * 0.15;

	// Sparse stars
	vec2 starUV = skyUV * vec2(42.0, 24.0);
	vec2 starCell = floor(starUV);
	vec2 starF = fract(starUV) - 0.5;
	float starSeed = fract(sin(dot(starCell, vec2(127.1, 311.7))) * 43758.5453);
	float starMask = step(0.985, starSeed);
	float star = smoothstep(0.03, 0.0, length(starF)) * starMask;
	base += vec3(0.85, 0.9, 1.0) * star * 0.8;

	return base;
}

#endif
