float getDist(vec3 pos){ // Compose your scene herex
	float cube = SDFbox(pos, vec3(-0.3, 0.0, 0.0), vec3(0.1)) - 0.01;
	float sphere = SDFsphere(pos, vec3(0.3, 0.0, 0.0), 0.1) - 0.01;
	return min(cube, sphere);
}

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