// Optimization test scene
// Purpose: stress distance-based LOD/step scaling with repeated geometry

#ifndef SCENE_OPTIMIZATION_TEST_GLSL
#define SCENE_OPTIMIZATION_TEST_GLSL

// O(1): Scene-specific lighting for optimization test
vec3 optimizationTestSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
	vec3 col = vec3(0.0);
	vec3 refRd = reflect(rd, normals);

#if RM_ENABLE_SPOTLIGHT
	{
		vec3 spotPos = vec3(0.0, 1.4, 0.3);
		vec3 spotTarget = vec3(0.0, 0.2, 2.0);
		vec3 spotDir = normalize(spotTarget - spotPos);
		vec3 spotCol = vec3(0.9, 0.95, 1.0) * 0.7;
		col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, 0.35, 0.9);
	}
#endif

	// Two point lights to reveal spec/shape
	{
		vec3 p1 = vec3(-0.8, 0.5, 0.8);
		vec3 c1 = vec3(0.6, 0.8, 1.0) * 0.7;
		col += getPointLight(hitPos, p1, normals, rd, refRd, c1, mate);
	}
	{
		vec3 p2 = vec3(0.9, 0.4, 1.8);
		vec3 c2 = vec3(1.0, 0.7, 0.5) * 0.6;
		col += getPointLight(hitPos, p2, normals, rd, refRd, c2, mate);
	}

	return col;
}

// O(1): Optimization test scene
// Returns: vec4(albedo.rgb, distance)
vec4 optimizationTestScene(vec3 pos) {
	SceneResult scene = sceneResult(1000.0, createMaterial(vec3(0.0)));

	// Ground plane for scale
	Material floorMat = createMaterial(vec3(0.08, 0.09, 0.11), 0.0, 0.6);
	scene = sceneMin(scene, sceneResult(fPlane(pos, vec3(0.0, 1.0, 0.0), 0.0), floorMat));

	// Repeated pillars along Z to exercise distance-based LOD
	for (int i = 0; i < 6; i++) {
		float idx = float(i);
		float z = 0.6 + idx * 0.8;
		float wobble = sin(iTime * 0.4 + idx) * 0.04;

		// Two columns per row
		vec3 colA = pos - vec3(-0.35, 0.18, z + wobble);
		vec3 colB = pos - vec3(0.35, 0.18, z - wobble);

		float columnA = fCapsule(colA, vec3(0.0, 0.0, 0.0), vec3(0.0, 0.6, 0.0), 0.06);
		float columnB = fCapsule(colB, vec3(0.0, 0.0, 0.0), vec3(0.0, 0.55, 0.0), 0.06);

		Material metalMat = createMaterial(vec3(0.22, 0.28, 0.35), 0.6, 0.2);
		Material rubberMat = createMaterial(vec3(0.15, 0.2, 0.26), 0.0, 0.85);

		scene = sceneMin(scene, sceneResult(columnA, metalMat));
		scene = sceneMin(scene, sceneResult(columnB, rubberMat));

		// Small orbiting beads around each row
		vec3 beadPos = pos - vec3(0.0, 0.4, z);
		mat3 rot = getRotationMatrix(normalize(vec3(0.2, 1.0, 0.1)), iTime * 0.6 + idx);
		vec3 beadOffset = rot * vec3(0.25, 0.0, 0.0);
		float bead = fSphere(beadPos + beadOffset, 0.06);
		Material beadMat = matGlow(vec3(0.4, 0.7, 1.0), 1.4);
		scene = sceneMin(scene, sceneResult(bead, beadMat));
	}

	// Far cluster to test step scaling
	vec3 clusterPos = pos - vec3(0.0, 0.4, 4.8);
	float cluster = fSphere(clusterPos, 0.35);
	Material clusterMat = createMaterial(vec3(0.2, 0.3, 0.5), 0.4, 0.3, vec3(0.0), 0.2);
	scene = sceneMin(scene, sceneResult(cluster, clusterMat));

	gMaterial = scene.mat;
	return vec4(scene.mat.albedo, scene.dist);
}

// O(1): Scene background
vec3 optimizationTestBackground(vec2 skyUV, vec3 rd, vec3 ro) {
	vec3 base = rmSkyBase(rd, ro);
	base *= vec3(0.2, 0.25, 0.35);
	base = mix(base, base * 0.6, smoothstep(0.15, 0.6, skyUV.y));
	return base;
}

#endif
