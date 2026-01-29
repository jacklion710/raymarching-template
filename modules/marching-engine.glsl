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
	vec3 cubePos = pos - vec3(0.15, cubeY, -0.35);
	mat3 rotMat = getRotationMatrix(normalize(vec3(1.0, 1.0, 1.0)), iTime * 0.9);
	cubePos = rotMat * cubePos;
	SceneResult cube = sceneResult(
		fBox(cubePos, vec3(0.06)),
		matMetal(vec3(1.0, 0.76, 0.33))  // Gold color
	);
	scene = sceneSmin(scene, cube, 0.05);
	
	// Glowing cyan sphere (floating, pulsing)
	float glowY = 0.12 + sin(iTime * 1.2) * 0.03;
	vec3 glowPos = pos - vec3(-0.15, glowY, -0.3);
	float glowPulse = 0.8 + 0.2 * sin(iTime * 2.0);
	SceneResult glowSphere = sceneResult(
		fSphere(glowPos, 0.05),
		matGlow(vec3(0.3, 0.9, 1.0), 4.0 * glowPulse)  // Bright cyan glow
	);
	scene = sceneMin(scene, glowSphere);
	
	// Set global material for lighting to use
	gMaterial = scene.mat;
	
	// Return legacy format for compatibility (albedo.rgb, dist)
	return vec4(scene.mat.albedo, scene.dist);
}

// O(1): Raymarching loop.
// ro: ray origin
// rd: ray direction
vec4 map(vec3 ro, vec3 rd){ // Raymarching loop
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