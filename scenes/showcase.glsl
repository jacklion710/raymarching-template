// Material showcase scene
// Demonstrates various material types: metals, plastics, SSS, iridescence, transparency, toon

#ifndef SCENE_SHOWCASE_GLSL
#define SCENE_SHOWCASE_GLSL

// O(1): Scene-specific lighting for material showcase
// Spotlights and point lights positioned to highlight each material row
// hitPos: surface hit position
// normals: surface normal
// rd: view ray direction
// mate: surface albedo
// Returns: additional light contribution from scene lights
vec3 showcaseSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
	vec3 col = vec3(0.0);
	
#if RM_ENABLE_SPOTLIGHT
	// Spotlight backlighting SSS row - creates rim lighting and backscatter
	{
		vec3 spotPos = vec3(0.0, 0.5, 1.2);
		vec3 spotTarget = vec3(0.0, 0.4, 0.0);
		vec3 spotDir = normalize(spotTarget - spotPos);
		vec3 spotCol = vec3(1.0, 0.98, 0.95) * 0.4;
		float innerAngle = 0.5;
		float outerAngle = 0.9;
		col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, innerAngle, outerAngle);
	}
	
	// Spotlight for transparent materials row - highlights refraction
	{
		vec3 transSpotPos = vec3(0.0, 0.9, 0.4);
		vec3 transSpotTarget = vec3(0.0, 0.56, 0.8);
		vec3 transSpotDir = normalize(transSpotTarget - transSpotPos);
		vec3 transSpotCol = vec3(1.0, 1.0, 1.0) * 0.5;
		float transInner = 0.4;
		float transOuter = 0.7;
		col += getSpotLight(hitPos, transSpotPos, transSpotDir, normals, rd, transSpotCol, transInner, transOuter);
	}
	
	// Point light behind glass row - casts colored caustic shadows forward onto floor
	{
		vec3 glassLight = vec3(-0.2, 0.4, 1.1);
		vec3 glassLightCol = vec3(1.0, 0.98, 0.95) * 0.6;
		col += getPointLight(hitPos, glassLight, normals, rd, reflect(rd, normals), glassLightCol, mate);
	}
	
	// Point light behind SSS row - casts colored bleeding shadows onto floor
	{
		vec3 sssLight = vec3(0.2, 0.35, 0.95);
		vec3 sssLightCol = vec3(1.0, 0.95, 0.9) * 0.5;
		col += getPointLight(hitPos, sssLight, normals, rd, reflect(rd, normals), sssLightCol, mate);
	}
	
	// Side light for iridescent row - casts rainbow shadows
	{
		vec3 iriLight = vec3(-0.6, 0.4, 0.6);
		vec3 iriLightCol = vec3(1.0, 1.0, 1.0) * 0.4;
		col += getPointLight(hitPos, iriLight, normals, rd, reflect(rd, normals), iriLightCol, mate);
	}
#endif
	
	return col;
}

// O(1): Material showcase scene - metals, plastics, SSS, iridescence, transparency, toon
// pos: world-space position being sampled
// Returns: vec4(albedo.rgb, distance)
vec4 showcaseScene(vec3 pos){
	
	// Ground plane: shiny floor for visible reflections
	Material planeMat = createMaterial(vec3(0.25), 0.0, 0.15);  // Low roughness = shiny
	float planeDist = fPlane(pos, vec3(0.0, 1.0, 0.0), 0.0);
	SceneResult scene = sceneResult(planeDist, planeMat);
	
	// Material showcase: 5 spheres in an arc
	float radius = 0.12;
	float spacing = 0.35;
	float y = radius + 0.02;  // Slightly above plane
	
	// Gentle floating animation
	float bounce = sin(iTime * 1.5) * 0.02;
	
	// === SMOOTH BLEND DEMO (LEFT) ===
	// Two spheres with different materials blended together
	// Demonstrates color + roughness interpolation
	float blendK = 0.08;  // Blend smoothness
	
	// Animation: oscillate position and size in opposite directions
	float blendAnim = sin(iTime * 1.2);
	float blendAnimOffset = sin(iTime * 1.2 + 3.14159);  // Opposite phase
	
	// Left blend: Blue plastic + Orange rubber
	vec3 blendL1 = pos - vec3(-spacing * 3.0 + blendAnim * 0.04, y + 0.15 + blendAnim * 0.02, 0.2);
	vec3 blendL2 = pos - vec3(-spacing * 2.7 + blendAnimOffset * 0.04, y + 0.18 + blendAnimOffset * 0.02, 0.25);
	float blendRadL1 = radius * (0.85 + blendAnim * 0.15);
	float blendRadL2 = radius * (0.85 + blendAnimOffset * 0.15);
	SceneResult blendLeft1 = sceneResult(
		fSphere(blendL1, blendRadL1),
		matPlastic(vec3(0.1, 0.4, 0.95))  // Blue
	);
	SceneResult blendLeft2 = sceneResult(
		fSphere(blendL2, blendRadL2),
		matRubber(vec3(0.95, 0.5, 0.1))   // Orange
	);
	SceneResult blendedLeft = sceneSmin(blendLeft1, blendLeft2, blendK);
	scene = sceneMin(scene, blendedLeft);
	
	// 1. Blue plastic (leftmost of main row)
	vec3 p1 = pos - vec3(-spacing * 2.0, y + bounce, 0.0);
	SceneResult s1 = sceneResult(
		fSphere(p1, radius),
		matPlastic(vec3(0.1, 0.3, 0.9))
	);
	scene = sceneMin(scene, s1);
	
	// 2. Copper metal
	vec3 p2 = pos - vec3(-spacing, y + bounce * 0.8, 0.1);
	SceneResult s2 = sceneResult(
		fSphere(p2, radius),
		matMetal(vec3(0.95, 0.64, 0.54))  // Copper color
	);
	scene = sceneMin(scene, s2);
	
	// 3. Mirror (center)
	vec3 p3 = pos - vec3(0.0, y + bounce * 0.6, 0.15);
	SceneResult s3 = sceneResult(
		fSphere(p3, radius),
		matMirror()
	);
	scene = sceneMin(scene, s3);
	
	// 4. Rough silver metal
	vec3 p4 = pos - vec3(spacing, y + bounce * 0.4, 0.1);
	SceneResult s4 = sceneResult(
		fSphere(p4, radius),
		matRoughMetal(vec3(0.75, 0.75, 0.78))  // Silver color
	);
	scene = sceneMin(scene, s4);
	
	// 5. Green rubber (rightmost of main row)
	vec3 p5 = pos - vec3(spacing * 2.0, y + bounce * 0.2, 0.0);
	SceneResult s5 = sceneResult(
		fSphere(p5, radius),
		matRubber(vec3(0.2, 0.7, 0.3))
	);
	scene = sceneMin(scene, s5);
	
	// === SMOOTH BLEND DEMO (RIGHT) ===
	// Metal + Matte blend - shows metallic property interpolation
	vec3 blendR1 = pos - vec3(spacing * 2.7 + blendAnimOffset * 0.04, y + 0.16 + blendAnimOffset * 0.02, 0.25);
	vec3 blendR2 = pos - vec3(spacing * 3.0 + blendAnim * 0.04, y + 0.13 + blendAnim * 0.02, 0.2);
	float blendRadR1 = radius * (0.85 + blendAnimOffset * 0.15);
	float blendRadR2 = radius * (0.85 + blendAnim * 0.15);
	SceneResult blendRight1 = sceneResult(
		fSphere(blendR1, blendRadR1),
		matGold()  // Shiny metallic
	);
	SceneResult blendRight2 = sceneResult(
		fSphere(blendR2, blendRadR2),
		matRubber(vec3(0.2, 0.8, 0.6))  // Matte teal
	);
	SceneResult blendedRight = sceneSmin(blendRight1, blendRight2, blendK);
	scene = sceneMin(scene, blendedRight);
	
	// Gold rotating cube (polished gold finish)
	float cubeY = 0.08 + sin(iTime * 0.8) * 0.04;
	vec3 cubePos = pos - vec3(0.0, cubeY, -0.45);
	mat3 rotMat = getRotationMatrix(normalize(vec3(1.0, 1.0, 1.0)), iTime * 0.9);
	cubePos = rotMat * cubePos;
	SceneResult cube = sceneResult(
		fBox(cubePos, vec3(0.06)),
		matGold()
	);
	scene = sceneSmin(scene, cube, 0.05);
	
#if RM_ENABLE_EMISSIVE
	// Emissive spheres (uses centralized multi-emissive definition)
	for (int i = 0; i < NUM_EMISSIVES; i++) {
		vec4 emissiveSource = getEmissiveSource(i);
		vec4 emissiveProps = getEmissiveProperties(i);
		vec3 glowPos = pos - emissiveSource.xyz;
		SceneResult glowSphere = sceneResult(
			fSphere(glowPos, emissiveSource.w),
			matGlow(emissiveProps.xyz, emissiveProps.w)
		);
		scene = sceneMin(scene, glowSphere);
	}
#endif
	
	// Subsurface scattering showcase: 4 spheres in a row (upper row)
#if RM_ENABLE_SSS
	float sssRadius = 0.1;
	float sssSpacing = 0.3;
	float sssY = 0.42 + sin(iTime * 0.6) * 0.01;
	float sssZ = 0.65;
	
	// 1. Wax (cream colored)
	vec3 sss1 = pos - vec3(-sssSpacing * 1.5, sssY, sssZ);
	SceneResult waxSphere = sceneResult(
		fSphere(sss1, sssRadius),
		matWax(vec3(0.95, 0.9, 0.8))
	);
	scene = sceneMin(scene, waxSphere);
	
	// 2. Skin
	vec3 sss2 = pos - vec3(-sssSpacing * 0.5, sssY + 0.01, sssZ - 0.05);
	SceneResult skinSphere = sceneResult(
		fSphere(sss2, sssRadius),
		matSkin(vec3(0.9, 0.7, 0.6))
	);
	scene = sceneMin(scene, skinSphere);
	
	// 3. Jade (green)
	vec3 sss3 = pos - vec3(sssSpacing * 0.5, sssY + 0.02, sssZ - 0.1);
	SceneResult jadeSphere = sceneResult(
		fSphere(sss3, sssRadius),
		matJade(vec3(0.2, 0.6, 0.3))
	);
	scene = sceneMin(scene, jadeSphere);
	
	// 4. Marble (rightmost)
	vec3 sss4 = pos - vec3(sssSpacing * 1.5, sssY + 0.03, sssZ - 0.15);
	SceneResult marbleSphere = sceneResult(
		fSphere(sss4, sssRadius),
		matMarble()
	);
	scene = sceneMin(scene, marbleSphere);
#endif
	
	// Iridescent material showcase: 4 spheres in a row above main materials
#if RM_ENABLE_IRIDESCENCE
	float iriRadius = 0.1;
	float iriSpacing = 0.3;
	float iriY = 0.28 + sin(iTime * 0.7) * 0.015;
	float iriZ = 0.4;
	
	// 1. Soap bubble (leftmost)
	vec3 iri1 = pos - vec3(-iriSpacing * 1.5, iriY, iriZ);
	SceneResult soapBubble = sceneResult(
		fSphere(iri1, iriRadius),
		matSoapBubble()
	);
	scene = sceneMin(scene, soapBubble);
	
	// 2. Oil slick
	vec3 iri2 = pos - vec3(-iriSpacing * 0.5, iriY + 0.01, iriZ - 0.05);
	SceneResult oilSlick = sceneResult(
		fSphere(iri2, iriRadius),
		matOilSlick()
	);
	scene = sceneMin(scene, oilSlick);
	
	// 3. Beetle shell (green)
	vec3 iri3 = pos - vec3(iriSpacing * 0.5, iriY + 0.02, iriZ - 0.1);
	SceneResult beetleShell = sceneResult(
		fSphere(iri3, iriRadius),
		matBeetleShell(vec3(0.1, 0.4, 0.2))
	);
	scene = sceneMin(scene, beetleShell);
	
	// 4. Pearl (rightmost)
	vec3 iri4 = pos - vec3(iriSpacing * 1.5, iriY + 0.03, iriZ - 0.15);
	SceneResult pearl = sceneResult(
		fSphere(iri4, iriRadius),
		matPearl()
	);
	scene = sceneMin(scene, pearl);
#endif

	// Transparent + toon showcase: row above SSS
#if RM_ENABLE_REFRACTION || RM_ENABLE_TOON
	float transRadius = 0.095;
	float transSpacing = 0.28;
	float transY = 0.56 + sin(iTime * 0.5) * 0.01;
	float transZ = 0.8;
	
#if RM_ENABLE_REFRACTION
	// Glass sphere - amber tint like antique bottle glass
	vec3 trans1 = pos - vec3(-transSpacing * 1.5, transY, transZ);
	SceneResult glassSphere = sceneResult(
		fSphere(trans1, transRadius),
		matGlass()
	);
	scene = sceneMin(scene, glassSphere);
	
	// Water sphere - deep aqua-cyan like tropical ocean
	vec3 trans2 = pos - vec3(-transSpacing * 0.5, transY + 0.01, transZ - 0.05);
	SceneResult waterSphere = sceneResult(
		fSphere(trans2, transRadius),
		matWater()
	);
	scene = sceneMin(scene, waterSphere);
	
	// Crystal sphere - amethyst purple gem with high refraction
	vec3 trans3 = pos - vec3(transSpacing * 0.5, transY + 0.02, transZ - 0.1);
	SceneResult crystalSphere = sceneResult(
		fSphere(trans3, transRadius),
		matCrystal()
	);
	scene = sceneMin(scene, crystalSphere);
#endif
	
#if RM_ENABLE_TOON
	vec3 trans4 = pos - vec3(transSpacing * 1.5, transY + 0.03, transZ - 0.15);
	SceneResult toonSphere = sceneResult(
		fSphere(trans4, transRadius),
		matToon(vec3(0.2, 0.6, 0.9), 4.0)
	);
	scene = sceneMin(scene, toonSphere);
#endif
#endif
	
	// Set global material for lighting to use
	gMaterial = scene.mat;
	
	// Return legacy format for compatibility (albedo.rgb, dist)
	return vec4(scene.mat.albedo, scene.dist);
}

// O(1): Scene-specific background
vec3 showcaseBackground(vec3 rd, vec3 ro, vec2 uv) {
	// Sky-like procedural background (world-space, follows camera rotation).
	return rmDefaultBackground(rd, ro);
}

#endif
