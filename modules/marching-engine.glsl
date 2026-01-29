// Scene result: holds distance and material together
struct SceneResult {
	float dist;
	Material mat;
};

// Helper to create a SceneResult
SceneResult sceneResult(float dist, Material mat) {
	return SceneResult(dist, mat);
}

// Combine two scene results, keeping the closer one
SceneResult sceneMin(SceneResult a, SceneResult b) {
	return (a.dist < b.dist) ? a : b;
}

// Smooth minimum blend of two scene results
SceneResult sceneSmin(SceneResult a, SceneResult b, float k) {
	float h = clamp(0.5 + 0.5 * (b.dist - a.dist) / k, 0.0, 1.0);
	float dist = mix(b.dist, a.dist, h) - k * h * (1.0 - h);
	Material mat = mixMaterial(b.mat, a.mat, h);
	return SceneResult(dist, mat);
}

// O(1): Get the distance bound to the nearest surface in the scene.
// pos: world-space position being sampled
vec4 getDist(vec3 pos){ // Compose your scene here
	
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
	
	// 1. Blue plastic (leftmost)
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
	
	// 5. Green rubber (rightmost)
	vec3 p5 = pos - vec3(spacing * 2.0, y + bounce * 0.2, 0.0);
	SceneResult s5 = sceneResult(
		fSphere(p5, radius),
		matRubber(vec3(0.2, 0.7, 0.3))
	);
	scene = sceneMin(scene, s5);
	
	// Gold rotating cube
	float cubeY = 0.08 + sin(iTime * 0.8) * 0.04;
	vec3 cubePos = pos - vec3(0.0, cubeY, -.85);
	mat3 rotMat = getRotationMatrix(normalize(vec3(1.0, 1.0, 1.0)), iTime * 0.9);
	cubePos = rotMat * cubePos;
	SceneResult cube = sceneResult(
		fBox(cubePos, vec3(0.06)),
		matMetal(vec3(1.0, 0.76, 0.33))  // Gold color
	);
	scene = sceneSmin(scene, cube, 0.05);
	
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
	
	// Subsurface scattering showcase: 4 spheres in a row (highest row)
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
	
	// Iridescent material showcase: 4 spheres in a row above main materials
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
	
	// Set global material for lighting to use
	gMaterial = scene.mat;
	
	// Return legacy format for compatibility (albedo.rgb, dist)
	return vec4(scene.mat.albedo, scene.dist);
}

// O(n): Raymarching loop.
// ro: ray origin
// rd: ray direction
vec4 map(vec3 ro, vec3 rd){
	float hitMap;
	float currDist = nearClip;
	float dist = 0; 
	vec4 scene;
	vec3 pos;
	
	for(int i = 0; i < MAX_STEPS; i++) {
		pos = ro + rd * currDist;
		scene = getDist(pos);
		dist = scene.w;
		currDist += dist;
		hitMap = i / MAX_STEPS - 1.0;
		if(abs(dist) < MIN_DIST || currDist > farClip){
			break;
		}
	}
	return vec4(scene.rgb, currDist);
}