// Palette concert-style showcase scene
// Focus: stylized palette-driven materials with metallic + emissive accents

#ifndef SCENE_PALETTE_CONCERT_GLSL
#define SCENE_PALETTE_CONCERT_GLSL

// O(1): Scene-specific lighting for palette concert showcase
vec3 paletteConcertSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
	vec3 col = vec3(0.0);
	vec3 refRd = reflect(rd, normals);
	float t = iTime;

	// Triad of orbiting lights with palette-driven hues
	for (int i = 0; i < 3; i++) {
		float idx = float(i);
		float angle = t * 0.35 + idx * 2.094;
		vec3 lightPosLocal = vec3(cos(angle) * 1.1, 0.8 + sin(angle * 1.3) * 0.2, sin(angle) * 1.1);
		PaletteSample p = rmPaletteConcert(fract(0.12 * t + idx * 0.23));
		vec3 lightCol = mix(p.albedo, p.specTint, 0.65) * (0.9 + p.glow * 0.6);
		col += getPointLight(hitPos, lightPosLocal, normals, rd, refRd, lightCol, mate);
	}

#if RM_ENABLE_SPOTLIGHT
	// Soft rim spotlight from above, neutral-ish to keep form readable
	{
		vec3 spotPos = vec3(0.0, 1.8, 0.4);
		vec3 spotTarget = vec3(0.0, 0.35, 0.0);
		vec3 spotDir = normalize(spotTarget - spotPos);
		vec3 spotCol = vec3(0.9, 0.95, 1.0) * 0.7;
		col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, 0.4, 0.9);
	}
#endif

	return col;
}

// O(1): Palette concert scene - ribbons, core blob, glow pylons
// Returns: vec4(albedo.rgb, distance)
vec4 paletteConcertScene(vec3 pos) {
	float t = iTime;
	float paletteT = fract(0.08 * t);
	PaletteSample palette = rmPaletteConcert(paletteT);
	SceneResult scene = sceneResult(1000.0, createMaterial(vec3(0.0)));

	// Center cluster position
	vec3 corePos = pos - vec3(0.0, 0.35, 0.0);

	// Organic blob core (smooth union of spheres)
	float wobble = sin(t * 0.7 + corePos.y * 3.0) * 0.02;
	float coreA = fSphere(corePos, 0.22 + wobble);
	float coreB = fSphere(corePos - vec3(0.18, 0.05, 0.06), 0.16);
	float coreC = fSphere(corePos + vec3(0.16, -0.03, -0.08), 0.14);
	float coreDist = smin(coreA, coreB, 0.12);
	coreDist = smin(coreDist, coreC, 0.12);

	Material coreMat = createMaterial(vec3(0.18, 0.32, 0.55), 0.25, 0.18, vec3(0.0), 0.45);
	coreMat = applyPaletteToMaterial(coreMat, palette, 0.55, RM_PALETTE_MODE_SPEC_TINT);
	coreMat = applyPaletteToMaterial(coreMat, palette, 0.7, RM_PALETTE_MODE_EMISSIVE);
	SceneResult core = sceneResult(coreDist, coreMat);
	scene = sceneMin(scene, core);

	// Glass shell (thin refractive layer)
	float shellDist = fSphere(corePos, 0.34);
	Material shellMat = Material(
		vec3(0.7, 0.85, 1.0),
		0.0, 0.02,
		vec3(0.0),
		0.2, 0.0, vec3(1.0),
		0.94, 1.45, 0.0
	);
	shellMat = applyPaletteToMaterial(shellMat, palette, 0.35, RM_PALETTE_MODE_ABSORPTION);
	SceneResult shell = sceneResult(shellDist, shellMat);
	scene = sceneMin(scene, shell);

	// Whispy goo ribbons (capsule chains)
	for (int i = 0; i < 6; i++) {
		float idx = float(i);
		float phase = t * 0.35 + idx * 1.2;
		vec3 a = vec3(sin(phase) * 0.5, 0.15 + sin(phase * 0.9) * 0.2, cos(phase) * 0.5);
		vec3 b = vec3(sin(phase + 1.3) * 0.55, 0.55 + cos(phase * 1.1) * 0.25, cos(phase + 1.3) * 0.55);
		float ribbon = fCapsule(pos, a, b, 0.035);
		PaletteSample p = rmPaletteConcert(fract(paletteT + idx * 0.12));
		Material ribbonMat = createMaterial(vec3(0.1, 0.2, 0.35), 0.1, 0.35, vec3(0.0), 0.25);
		ribbonMat = applyPaletteToMaterial(ribbonMat, p, 0.4, RM_PALETTE_MODE_ALBEDO);
		ribbonMat = applyPaletteToMaterial(ribbonMat, p, 0.85, RM_PALETTE_MODE_EMISSIVE);
		scene = sceneMin(scene, sceneResult(ribbon, ribbonMat));
	}

	// Metallic ribbon rings
	vec3 ringPos = corePos;
	mat3 ringRotA = getRotationMatrix(normalize(vec3(0.2, 1.0, 0.15)), t * 0.3);
	mat3 ringRotB = getRotationMatrix(normalize(vec3(1.0, 0.1, 0.5)), -t * 0.22);

	float ringA = fTorus(ringRotA * ringPos, 0.03, 0.38);
	Material ringMatA = createMaterial(vec3(0.18, 0.3, 0.5), 0.75, 0.08, vec3(0.0), 0.2);
	ringMatA = applyPaletteToMaterial(ringMatA, palette, 0.65, RM_PALETTE_MODE_SPEC_TINT);
	scene = sceneMin(scene, sceneResult(ringA, ringMatA));

	float ringB = fTorus(ringRotB * ringPos, 0.02, 0.3);
	Material ringMatB = createMaterial(vec3(0.12, 0.24, 0.4), 0.55, 0.18, vec3(0.0), 0.0);
	ringMatB = applyPaletteToMaterial(ringMatB, palette, 0.5, RM_PALETTE_MODE_ALBEDO);
	scene = sceneMin(scene, sceneResult(ringB, ringMatB));

	// Glow pylons around the core
	for (int i = 0; i < 4; i++) {
		float idx = float(i);
		float angle = idx * 1.5708 + t * 0.2;
		vec3 pylonPos = pos - vec3(cos(angle) * 0.7, 0.12, sin(angle) * 0.7);
		float pylonDist = fCapsule(pylonPos, vec3(0.0, 0.0, 0.0), vec3(0.0, 0.35, 0.0), 0.03);

		PaletteSample p = rmPaletteConcert(fract(paletteT + idx * 0.18));
		Material glowMat = matGlow(p.emissive, 2.6);
		scene = sceneMin(scene, sceneResult(pylonDist, glowMat));
	}

	gMaterial = scene.mat;
	return vec4(scene.mat.albedo, scene.dist);
}

// O(1): Scene-specific background
vec3 paletteConcertBackground(vec2 skyUV, vec3 rd, vec3 ro) {
	vec3 base = rmSkyBase(rd, ro) * 0.2;
	float t = iTime;

	PaletteSample p = rmPaletteConcert(fract(0.05 * t + skyUV.y * 0.4));
	vec3 band = mix(p.albedo, p.specTint, 0.5);

	float horizon = smoothstep(0.08, 0.45, skyUV.y);
	base = mix(base, band, horizon * 0.5);

	// Soft neon arc across the sky (stronger for glow)
	float arc = smoothstep(0.14, 0.0, abs(skyUV.y - 0.65));
	base += p.emissive * arc * 0.35;

	return base;
}

#endif
