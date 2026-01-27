// O(1): Get the distance bound to the nearest surface in the scene.
// pos: world-space position being sampled
vec4 getDist(vec3 pos){ // Compose your scene here
	vec4 plane = vec4(0.1, 0.9, 0.12, fPlane(pos, vec3(0.0, 1.0, 0.0), 0.0));

	// Box vertical motion:
	// - Intersecting the plane when centerY < halfSizeY (0.1)
	// - Levitating when centerY > halfSizeY (+ a small gap)
	const vec3 boxHalfSize = vec3(0.1, 0.1, 0.1);
	const float boxIntersectCenterY = 0.06;
	const float boxLevitateCenterY  = 0.18;
	float boxAnim01 = 0.5 + 0.5 * sin(iTime * 1.5); // [0..1]
	float boxCenterY = mix(boxIntersectCenterY, boxLevitateCenterY, boxAnim01);

	vec4 box = vec4(
		0.9, 0.1, 0.12,
		fBox(pos - vec3(0.0, boxCenterY, 0.0), boxHalfSize)
	);
	return getSmax(plane, box, 0.2);
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