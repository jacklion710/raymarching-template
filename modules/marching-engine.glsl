// O(1): Get the distance to the nearest object in the scene.
// pos: world-space position being sampled
float getDist(vec3 pos){ // Compose your scene herex
	float closest;
	float ra = (sin(pos.y*100)*0.5 + 0.5);
	ra *= (sin(pos.x*80)*0.5 + 0.5);
	ra *= (sin(pos.z*30)*0.5 + 0.5);
	ra *= 0.1;
	ra += 0.2;
	closest = SDFsphere(pos, vec3(sin(iTime * 0.1), 0.0, 0.0), ra);
	closest = smin(closest, SDFsphere(pos, vec3(sin(iTime * 0.2), 0.0, 0.0), ra), 0.4);
	return closest;
}

// O(1): Raymarching loop.
// ro: ray origin
// rd: ray direction
float map(vec3 ro, vec3 rd){ // Raymarching loop
	float hitMap;
	float currDist = 0;
	float dist = 0; 
	vec3 pos;
	for(int i = 0; i < MAX_STEPS; i++) {
		pos = ro + rd * currDist;
		dist = getDist(pos);
		currDist += dist;
		hitMap = i / MAX_STEPS - 1.0;
		if(dist < MIN_DIST || currDist > MAX_DIST){
			break;
		}
	}
	return currDist;
}