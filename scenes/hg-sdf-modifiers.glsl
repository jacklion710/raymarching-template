// hg_sdf modifiers gallery scene
// A compact "operator gallery" showcasing hg_sdf boolean/edge operators and domain manipulation.

#ifndef SCENE_HG_SDF_MODIFIERS_GLSL
#define SCENE_HG_SDF_MODIFIERS_GLSL

// O(1): Scene-specific lighting tuned for crisp edge readability.
// Uses a warm key, cool fill, and a subtle rim to emphasize modifier silhouettes.
vec3 hgSdfModifiersSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
	vec3 col = vec3(0.0);
	vec3 refRd = reflect(rd, normals);

#if RM_ENABLE_SPOTLIGHT
	// Key spotlight aimed at the front row
	vec3 spotPos = vec3(-1.2, 1.5, 1.4);
	vec3 spotTarget = vec3(0.0, 0.18, 0.4);
	vec3 spotDir = normalize(spotTarget - spotPos);
	vec3 spotCol = vec3(1.0, 0.92, 0.82) * 1.25;
	col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, 0.22, 0.52);
#endif

	// Cool fill from camera-right
	vec3 fillPos = vec3(1.6, 0.95, 0.2);
	vec3 fillCol = vec3(0.65, 0.82, 1.0) * 0.85;
	col += getPointLight(hitPos, fillPos, normals, rd, refRd, fillCol, mate);

	// Rim light from behind
	vec3 rimPos = vec3(0.0, 1.0, -1.5);
	vec3 rimCol = vec3(1.0, 0.75, 0.55) * 0.55;
	col += getPointLight(hitPos, rimPos, normals, rd, refRd, rimCol, mate);

	return col;
}

// O(1): hg_sdf operator gallery scene.
// Returns: vec4(albedo.rgb, distance)
vec4 hgSdfModifiersScene(vec3 pos) {
	// Ground plane with reflections to show carved details
	Material planeMat = createMaterial(vec3(0.14, 0.14, 0.16), 0.0, 0.32);
	SceneResult scene = sceneResult(fPlane(pos, vec3(0.0, 1.0, 0.0), 0.0), planeMat);

	// Layout parameters
	float baseY = 0.16;
	float baseZ = 0.4;
	float xStep = 0.48;  // Wider spacing between objects

	// Pedestal under the gallery
	vec3 plinthPos = pos - vec3(0.0, 0.05, baseZ);
	float plinth = fBox(plinthPos, vec3(1.55, 0.05, 0.48));
	Material plinthMat = createMaterial(vec3(0.11, 0.11, 0.12), 0.0, 0.22);
	scene = sceneMin(scene, sceneResult(plinth, plinthMat));

	// Animation time
	float spin = iTime * 0.35;

	// 1) CHAMFER UNION - 45-degree chamfered edge between two boxes
	vec3 p1 = pos - vec3(-xStep * 2.5, baseY, baseZ);
	mat3 r1 = getRotationMatrix(normalize(vec3(0.2, 1.0, 0.1)), spin);
	p1 = r1 * p1;
	float chamferA = fBox(p1 - vec3(-0.06, 0.0, 0.0), vec3(0.09, 0.10, 0.09));
	float chamferB = fBox(p1 - vec3(0.06, 0.0, 0.0), vec3(0.09, 0.10, 0.09));
	float chamferUnion = fOpUnionChamfer(chamferA, chamferB, 0.05);
	scene = sceneMin(scene, sceneResult(chamferUnion, matPlastic(vec3(0.16, 0.55, 0.95))));

	// 2) ROUND UNION - smooth blend between box and sphere
	vec3 p2 = pos - vec3(-xStep * 1.5, baseY, baseZ);
	mat3 r2 = getRotationMatrix(normalize(vec3(0.0, 1.0, 0.0)), -spin * 0.9);
	p2 = r2 * p2;
	float roundBox = fBox(p2 - vec3(-0.04, 0.0, 0.0), vec3(0.08, 0.09, 0.08));
	float roundSph = fSphere(p2 - vec3(0.09, 0.02, 0.03), 0.10);
	float roundUnion = fOpUnionRound(roundBox, roundSph, 0.07);
	scene = sceneMin(scene, sceneResult(roundUnion, matRubber(vec3(0.95, 0.42, 0.12))));

	// 3) STAIRS UNION - stepped transition between two boxes
	vec3 p3 = pos - vec3(-xStep * 0.5, baseY, baseZ);
	mat3 r3 = getRotationMatrix(normalize(vec3(0.8, 1.0, 0.2)), spin * 0.75);
	p3 = r3 * p3;
	float stairsA = fBox(p3 - vec3(-0.06, 0.0, 0.0), vec3(0.10, 0.10, 0.10));
	float stairsB = fBox(p3 - vec3(0.06, 0.0, 0.0), vec3(0.10, 0.10, 0.10));
	float stairsUnion = fOpUnionStairs(stairsA, stairsB, 0.11, 6.0);
	scene = sceneMin(scene, sceneResult(stairsUnion, createMaterial(vec3(0.90, 0.86, 0.75), 0.0, 0.35)));

	// 4) ROUND DIFFERENCE - soft spherical cut from a box
	vec3 p4 = pos - vec3(xStep * 0.5, baseY, baseZ);
	mat3 r4 = getRotationMatrix(normalize(vec3(0.25, 1.0, 0.5)), -spin * 0.7);
	p4 = r4 * p4;
	float diffBody = fBox(p4, vec3(0.12, 0.10, 0.12));
	float diffCutter = fSphere(p4 - vec3(0.03, 0.02, 0.08), 0.14);
	float roundDiff = fOpDifferenceRound(diffBody, diffCutter, 0.05);
	scene = sceneMin(scene, sceneResult(roundDiff, matRoughMetal(vec3(0.78, 0.80, 0.85))));

	// 5) ENGRAVE - V-shaped groove cut into a box
	vec3 p5 = pos - vec3(xStep * 1.5, baseY, baseZ);
	mat3 r5 = getRotationMatrix(normalize(vec3(0.0, 1.0, 0.0)), spin * 0.8);
	p5 = r5 * p5;
	float engraveBase = fBox(p5, vec3(0.12, 0.10, 0.12));
	float engraveTool = fTorus(p5 - vec3(0.0, 0.02, 0.0), 0.04, 0.09);
	float engraved = fOpEngrave(engraveBase, engraveTool, 0.04);
	scene = sceneMin(scene, sceneResult(engraved, matPlastic(vec3(0.20, 0.92, 0.62))));

	// 6) PIPE - tube along intersection of sphere and box
	vec3 p6 = pos - vec3(xStep * 2.5, baseY, baseZ);
	mat3 r6 = getRotationMatrix(normalize(vec3(1.0, 1.0, 0.0)), spin * 0.6);
	p6 = r6 * p6;
	float pipeSph = fSphere(p6 - vec3(-0.04, 0.02, 0.02), 0.14);
	float pipeBox = fBox(p6 - vec3(0.04, 0.0, 0.0), vec3(0.12, 0.12, 0.12));
	float pipe = fOpPipe(pipeSph, pipeBox, 0.05);
	scene = sceneMin(scene, sceneResult(pipe, matGold()));

	// HERO: POLAR DOMAIN MOD - capsule spikes repeated around a sphere
	vec3 heroCenter = vec3(0.0, 0.28, -0.55);
	vec3 pH = pos - heroCenter;
	mat3 rH = getRotationMatrix(vec3(0.0, 1.0, 0.0), spin * 0.55);
	pH = rH * pH;
	vec2 polarXZ = pH.xz;
	pModPolar(polarXZ, 12.0);
	pH.xz = polarXZ;
	pH.x -= 0.38;
	float heroSpike = fCapsule(pH, 0.035, 0.14);
	float heroCore = fSphere(pos - heroCenter, 0.12);
	float hero = fOpUnionRound(heroSpike, heroCore, 0.07);
	scene = sceneMin(scene, sceneResult(hero, matMirror()));

	gMaterial = scene.mat;
	return vec4(scene.mat.albedo, scene.dist);
}

// O(1): Scene-specific background.
vec3 hgSdfModifiersBackground(vec2 skyUV, vec3 rd, vec3 ro) {
	vec3 base = rmDefaultBackground(rd, ro);

	// Slightly higher contrast sky for crisp silhouettes
	float vign = smoothstep(0.0, 0.65, 1.0 - dot(skyUV - 0.5, skyUV - 0.5) * 2.0);
	base *= mix(0.88, 1.06, vign);

	// Subtle horizon band for depth context
	float horizon = smoothstep(0.46, 0.52, skyUV.y);
	base = mix(base, vec3(0.95, 0.86, 0.78), horizon * 0.12);

	return base;
}

#endif
