// O(1): Get the distance bound to the nearest surface in the scene.
// pos: world-space position being sampled
vec4 getDist(vec3 pos){ // Compose your scene here
	vec3 colSphere = vec3(0.9, 0.1, 0.12);
	vec3 colPlane = vec3(0.1, 0.1, 0.9);
	// Create an infinite plane of glowing spheres (like a glowing orb array in space)

	// cell size for repetition (space between spheres)
	vec3 cellSize = vec3(0.8, 0.0, 0.8); // set y to zero for infinite grid in xz plane

	// "snap" position to repeating cell along xz plane,
	// keep y coordinate for vertical offset (let y offset the spheres from the plane)
	vec3 cell = vec3(cellSize.x, 0.0, cellSize.z);
	vec3 q = pos - vec3(
		cell.x * floor((pos.x + 0.5*cell.x)/cell.x),
		0.0,
		cell.z * floor((pos.z + 0.5*cell.z)/cell.z)
	);

	// sphere position also lifted a bit above the ground
	q.y = pos.y - 0.3;

	// Signed distance to sphere
	float sphere = fSphere(q, 0.3);
	
	// Flat plane at y=0
	float plane = fPlane(pos, vec3(0.0, 1.0, 0.0), 0.0);

	// vec4(albedoRGB, distance)
	vec4 sphereSdf = vec4(colSphere, sphere);
	vec4 planeSdf  = vec4(colPlane,  plane);

	// Combine: union, returning the albedo for the closest surface.
	return getMin(sphereSdf, planeSdf);
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