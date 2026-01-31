// Subsurface scattering demo scene
// Purpose-built to show thickness, backlighting, and rim scatter interactions

#ifndef SCENE_SSS_DEMO_GLSL
#define SCENE_SSS_DEMO_GLSL

// O(1): Scene-specific lighting for SSS demo.
// Designed to create strong backlighting and rim conditions.
vec3 sssDemoSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
	vec3 col = vec3(0.0);
	vec3 refRd = reflect(rd, normals);

#if RM_ENABLE_SPOTLIGHT
	// Back spotlight for strong translucency (primary SSS showcase)
	{
		vec3 spotPos = vec3(0.0, 0.55, 1.35);
		vec3 spotTarget = vec3(0.0, 0.22, 0.45);
		vec3 spotDir = normalize(spotTarget - spotPos);
		vec3 spotCol = vec3(1.0, 0.92, 0.8) * 2.2;
		col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, 0.18, 0.55);
	}

	// Narrow kicker for edge/rim scattering
	{
		vec3 spotPos = vec3(-0.95, 0.35, 0.65);
		vec3 spotTarget = vec3(-0.35, 0.2, 0.45);
		vec3 spotDir = normalize(spotTarget - spotPos);
		vec3 spotCol = vec3(0.8, 0.9, 1.0) * 1.1;
		col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, 0.12, 0.35);
	}
#endif

	// Soft fill point light to keep shadows readable
	{
		vec3 fillPos = vec3(0.85, 0.85, -0.15);
		vec3 fillCol = vec3(1.0, 1.0, 1.0) * 0.7;
		col += getPointLight(hitPos, fillPos, normals, rd, refRd, fillCol, mate);
	}

	return col;
}

// O(1): SSS demo scene.
// Returns vec4(albedo.rgb, distance)
vec4 sssDemoScene(vec3 pos) {

	// Ground plane: warm matte floor makes translucent shadows and rim light easier to see
	Material planeMat = createMaterial(vec3(0.85, 0.83, 0.8), 0.0, 0.85);
	float planeDist = fPlane(pos, vec3(0.0, 1.0, 0.0), 0.0);
	SceneResult scene = sceneResult(planeDist, planeMat);

#if RM_ENABLE_SSS
	// === 1) THIN "EAR" SLAB (SKIN) ===
	// Thin geometry makes backlighting and rim scatter very obvious.
	{
		vec3 c = vec3(-0.55, 0.2, 0.45);
		vec3 p = pos - c;

		float slab = fBox(p, vec3(0.20, 0.16, 0.035));
		float cavity = fSphere(p - vec3(0.08, 0.02, 0.0), 0.20);
		float notch = fBox(p - vec3(-0.12, -0.04, 0.0), vec3(0.07, 0.06, 0.06));

		float ear = fOpDifferenceRound(slab, cavity, 0.04);
		ear = fOpDifferenceRound(ear, notch, 0.03);

		SceneResult earObj = sceneResult(ear, matSkin(vec3(0.92, 0.72, 0.62)));
		scene = sceneMin(scene, earObj);
	}

	// === 2) HOLLOW SHELL (JADE) ===
	// Constant wall thickness demonstrates how thickness affects SSS intensity.
	{
		vec3 c = vec3(0.05, 0.19, 0.85);
		vec3 p = pos - c;

		float outer = fSphere(p, 0.165);
		float inner = fSphere(p, 0.138);
		float shell = fOpDifferenceRound(outer, inner, 0.02);

		// Window cut to expose wall thickness variation near the edge
		float window = fBox(p - vec3(0.06, 0.02, 0.0), vec3(0.08, 0.12, 0.20));
		shell = fOpDifferenceRound(shell, window, 0.015);

		SceneResult shellObj = sceneResult(shell, matJade(vec3(0.18, 0.55, 0.28)));
		scene = sceneMin(scene, shellObj);
	}

	// === 3) THICK SOLID REFERENCE (MARBLE) ===
	// Thicker object shows reduced backlit glow and more surface lighting.
	{
		vec3 c = vec3(0.62, 0.16, 0.38);
		vec3 p = pos - c;
		float d = fSphere(p, 0.145);
		SceneResult marbleObj = sceneResult(d, matMarble());
		scene = sceneMin(scene, marbleObj);
	}

	// === 4) "GUMMY BEAR" (CANDY) ===
	// Rounded multi-sphere silhouette to highlight backscatter and rim glow.
	{
		vec3 c = vec3(0.0, 0.165, 0.28);
		vec3 p = pos - c;

		// Body + head
		float body = fSphere(p - vec3(0.0, -0.02, 0.0), 0.13);
		float head = fSphere(p - vec3(0.0, 0.12, 0.0), 0.10);
		float bear = fOpUnionRound(body, head, 0.06);

		// Ears
		float earL = fSphere(p - vec3(-0.07, 0.20, 0.02), 0.045);
		float earR = fSphere(p - vec3(0.07, 0.20, 0.02), 0.045);
		bear = fOpUnionRound(bear, earL, 0.04);
		bear = fOpUnionRound(bear, earR, 0.04);

		// Arms (capsules)
		float armL = fCapsule(p, vec3(-0.12, 0.05, 0.02), vec3(-0.06, 0.00, 0.02), 0.04);
		float armR = fCapsule(p, vec3(0.12, 0.05, 0.02), vec3(0.06, 0.00, 0.02), 0.04);
		bear = fOpUnionRound(bear, armL, 0.04);
		bear = fOpUnionRound(bear, armR, 0.04);

		// Legs (capsules)
		float legL = fCapsule(p, vec3(-0.06, -0.10, 0.02), vec3(-0.06, -0.02, 0.02), 0.045);
		float legR = fCapsule(p, vec3(0.06, -0.10, 0.02), vec3(0.06, -0.02, 0.02), 0.045);
		bear = fOpUnionRound(bear, legL, 0.04);
		bear = fOpUnionRound(bear, legR, 0.04);

		SceneResult gummyBear = sceneResult(bear, matGummyBear(vec3(0.95, 0.15, 0.12)));
		scene = sceneMin(scene, gummyBear);
	}

	// Optional: a small wax sphere close to the floor to show soft translucent shadow edges
	{
		// Keep it away from the gummy bear silhouette.
		vec3 c = vec3(-0.85, 0.11, 0.05);
		vec3 p = pos - c;
		float d = fSphere(p, 0.11);
		SceneResult waxObj = sceneResult(d, matWax(vec3(0.95, 0.9, 0.82)));
		scene = sceneMin(scene, waxObj);
	}
#endif

	// Set global material for lighting to use
	gMaterial = scene.mat;

	// Return legacy format for compatibility (albedo.rgb, dist)
	return vec4(scene.mat.albedo, scene.dist);
}

#endif

