// O(1): Get the distance bound to the nearest surface in the scene.
// pos: world-space position being sampled
vec4 getDist(vec3 pos){ // Compose your scene here
	// Plane with a cube moving in the y axis
	// Non-black albedo so colored lights are visible on it.
	vec4 plane = vec4(vec3(0.1), fPlane(pos, vec3(0.0, 1.0, 0.0), 0.0));

	// Box motion: intersects plane, then levitates above it.
	float boxAnim01 = 0.5 + 0.5 * sin(iTime * 0.8); // [0..1]
	float boxCenterY = mix(0.06, 0.18, boxAnim01);
	vec3 boxPos = vec3(0.0, boxCenterY, 0.0);

	// float sphereCenterY = mix(0.9, .8, 0.8);
	// vec3 spherePos = vec3(-0.33, sphereCenterY, 0.0);
	vec3 spherePos = vec3(-0.33, 0.66, 0.0);

	// Diagonal rotation (around axis (1,1,1)) in the box's local space.
	vec3 boxLocalPos = pos - boxPos;
	vec3 rotAxis = normalize(vec3(1.0, 1.0, 1.0));
	mat3 rotMat = getRotationMatrix(rotAxis, iTime * 0.9);
	boxLocalPos = rotMat * boxLocalPos;
	
	vec3 sphereLocalPos = pos - spherePos;
	sphereLocalPos = rotMat * sphereLocalPos;
	
	vec4 box = vec4(0.9, 0.1, 0.12, fBox(boxLocalPos, vec3(0.1, 0.1, 0.1)));
	vec4 sphere = vec4(0.9, 0.1, 0.12, fSphere(sphereLocalPos, 0.1));

	vec4 closest = getMin(box, sphere);
	return getSmin(plane, closest, 0.18);
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