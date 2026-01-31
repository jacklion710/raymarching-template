// Environment map demo scene
// Showcases reflective materials against a high-contrast sky background

#ifndef SCENE_ENV_MAP_DEMO_GLSL
#define SCENE_ENV_MAP_DEMO_GLSL

// O(1): Scene-specific lighting optimized for reflection read
vec3 envMapSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
	vec3 col = vec3(0.0);
	vec3 refRd = reflect(rd, normals);

#if RM_ENABLE_SPOTLIGHT
	// Key spotlight aimed at the hero mirror sphere
	{
		vec3 spotPos = vec3(-0.9, 1.2, 0.9);
		vec3 spotTarget = vec3(-0.55, 0.2, 0.05);
		vec3 spotDir = normalize(spotTarget - spotPos);
		vec3 spotCol = vec3(1.0, 0.9, 0.78) * 1.4;
		col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, 0.25, 0.55);
	}
#endif

	// Cool fill light from the right
	{
		vec3 pointPos = vec3(1.1, 0.7, 0.2);
		vec3 pointCol = vec3(0.6, 0.8, 1.0) * 1.1;
		col += getPointLight(hitPos, pointPos, normals, rd, refRd, pointCol, mate);
	}

	// Rim light from behind
	{
		vec3 pointPos = vec3(0.0, 0.9, -1.1);
		vec3 pointCol = vec3(1.0, 0.7, 0.5) * 0.8;
		col += getPointLight(hitPos, pointPos, normals, rd, refRd, pointCol, mate);
	}

	return col;
}

// O(1): Environment map demo scene
vec4 envMapScene(vec3 pos) {
	// Dark matte floor to emphasize reflections
	Material floorMat = createMaterial(vec3(0.12, 0.12, 0.14), 0.0, 0.85);
	SceneResult scene = sceneResult(fPlane(pos, vec3(0.0, 1.0, 0.0), 0.0), floorMat);

	// Mirror hero sphere
	vec3 mirrorPos = pos - vec3(-0.55, 0.18, 0.05);
	SceneResult mirrorSphere = sceneResult(
		fSphere(mirrorPos, 0.18),
		matMirror()
	);
	scene = sceneMin(scene, mirrorSphere);

	// Polished chrome torus
	vec3 torusPos = pos - vec3(0.4, 0.2, 0.1);
	mat3 torusRot = getRotationMatrix(normalize(vec3(1.0, 1.0, 0.0)), 0.75);
	torusPos = torusRot * torusPos;
	SceneResult chromeTorus = sceneResult(
		fTorus(torusPos, 0.04, 0.16),
		matMetal(vec3(0.85, 0.9, 0.95))
	);
	scene = sceneMin(scene, chromeTorus);

	// Glass sphere with slight tint
	vec3 glassPos = pos - vec3(0.0, 0.14, -0.4);
	Material glassMat = Material(
		vec3(0.85, 0.95, 1.0),
		0.0, 0.03,
		vec3(0.0),
		0.0, 0.0, vec3(1.0),
		0.95, 1.52, 0.0
	);
	SceneResult glassSphere = sceneResult(
		fSphere(glassPos, 0.14),
		glassMat
	);
	scene = sceneMin(scene, glassSphere);

	// Brushed metal plinth
	vec3 plinthPos = pos - vec3(0.8, 0.08, -0.2);
	SceneResult plinth = sceneResult(
		fBox(plinthPos, vec3(0.22, 0.08, 0.18)),
		createMaterial(vec3(0.55, 0.58, 0.62), 1.0, 0.55)
	);
	scene = sceneMin(scene, plinth);

	// Iridescent bead for spectrum reflections
#if RM_ENABLE_IRIDESCENCE
	vec3 beadPos = pos - vec3(0.55, 0.12, 0.45);
	SceneResult bead = sceneResult(
		fSphere(beadPos, 0.1),
		matBeetleShell(vec3(0.15, 0.25, 0.4))
	);
	scene = sceneMin(scene, bead);
#endif

	gMaterial = scene.mat;
	return vec4(scene.mat.albedo, scene.dist);
}

// O(1): Scene-specific background (used as env map)
vec3 envMapBackground(vec2 skyUV, vec3 rd, vec3 ro) {
	vec3 base = rmSkyBase(rd, ro);

	// High-contrast horizon band
	float horizon = smoothstep(0.47, 0.52, skyUV.y);
	vec3 bandCol = vec3(0.95, 0.75, 0.55);
	base = mix(base, bandCol, horizon * 0.35);

	// Bold geometric tessellation (obvious pattern for env reflections)
	vec2 grid = skyUV * vec2(18.0, 10.0);
	vec2 cell = floor(grid);
	vec2 f = fract(grid) - 0.5;
	float checker = mod(cell.x + cell.y, 2.0);

	// Diamond tile mask
	float diamond = smoothstep(0.48, 0.38, abs(f.x) + abs(f.y));
	vec3 tileA = vec3(0.12, 0.22, 0.35);
	vec3 tileB = vec3(0.65, 0.78, 0.92);
	vec3 tileCol = mix(tileA, tileB, checker);
	base = mix(base, tileCol, diamond * 0.65);

	// Overprint thin grid lines
	float lineX = smoothstep(0.48, 0.46, abs(f.x));
	float lineY = smoothstep(0.48, 0.46, abs(f.y));
	float gridLine = max(lineX, lineY);
	base = mix(base, vec3(0.95, 0.92, 0.88), gridLine * 0.25);

	// Soft vignette toward poles
	float poleFade = smoothstep(0.0, 0.22, skyUV.y) * smoothstep(1.0, 0.78, skyUV.y);
	base *= mix(0.8, 1.0, poleFade);

	return base;
}

#endif
