// O(1): Get the distance bound to the nearest surface in the scene.
// pos: world-space position being sampled
vec4 getDist(vec3 pos){ // Compose your scene here
	// Animate sphere through box (inside/outside) for inspection.
	const vec3 boxHalfSize = vec3(0.1, 0.1, 0.1);
	const float sphereRadius = 0.12;
	const float kBlend = 0.18;

	// Two side-by-side copies:
	// - Left: smooth union (getSmin)
	// - Right: smooth intersection (getSmax)
	const float sceneOffsetX = 0.45;

	// Box center moves up/down a bit, sphere moves through in X so you can inspect overlap.
	float boxAnim01 = 0.5 + 0.5 * sin(iTime * 1.5);
	float boxCenterY = mix(0.10, 0.16, boxAnim01);
	float sphereX = sin(iTime * 0.8) * 0.28;

	// Left (union)
	vec3 pUnion = pos - vec3(-sceneOffsetX, 0.0, 0.0);
	vec4 boxUnion = vec4(
		0.9, 0.1, 0.12,
		fBox(pUnion - vec3(0.0, boxCenterY, 0.0), boxHalfSize)
	);
	vec4 sphereUnion = vec4(
		0.12, 0.35, 0.95,
		fSphere(pUnion - vec3(sphereX, boxCenterY, 0.0), sphereRadius)
	);
	vec4 unionShape = getSmax(boxUnion, sphereUnion, kBlend);

	// Right (intersection)
	vec3 pInter = pos - vec3(sceneOffsetX, 0.0, 0.0);
	vec4 boxInter = vec4(
		0.9, 0.1, 0.12,
		fBox(pInter - vec3(0.0, boxCenterY, 0.0), boxHalfSize)
	);
	vec4 sphereInter = vec4(
		0.12, 0.35, 0.95,
		fSphere(pInter - vec3(sphereX, boxCenterY, 0.0), sphereRadius)
	);
	vec4 interShape = getSmin(boxInter, sphereInter, kBlend);

	// Combine both copies into one scene.
	return getMin(unionShape, interShape);
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
		if(dist < MIN_DIST || currDist > farClip){
			break;
		}
	}
	return vec4(scene.rgb, currDist);
}