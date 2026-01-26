// Forward declaration (the full scene SDF is defined in the main fragment source).
float getDist(vec3 pos);

// O(1): Normal calculation for lighting.
// hitPos: hit position
vec3 getNorm(vec3 hitPos){ // Normal calculation for lighting
	vec2 eps = vec2(0.00001, 0.0);
	float shiftX = getDist(hitPos + eps.xyy) - getDist(hitPos - eps.xyy);
	float shiftY = getDist(hitPos + eps.yxy) - getDist(hitPos - eps.yxy);
	float shiftZ = getDist(hitPos + eps.yyx) - getDist(hitPos - eps.yyx);
	return normalize(vec3(shiftX, shiftY, shiftZ));
}

// O(1): Ambient occlusion calculation.
// hitPos: hit position
// normal: normal vector
float getAmbientOcclusion(vec3 hitPos, vec3 normal){
	float occ = 0.0;
	float sca = 1.0;
	for(int i = 0; i < 5; i++){
		float h = 0.01 + 0.12 * float(i) / 4.0;
		float d = getDist(hitPos + normal * h);
		occ += (h - d) * sca;
		sca *= 0.5;
	}
	return clamp(1.0 - 6.0 * occ, 0.0, 1.0);
}

// O(1): Shadow calculation.
// hitPos: hit position
// rd: ray direction
float getShadow(vec3 hitPos, vec3 rd){
	for (float h = 0.01; h < 3.0; ){
		float d = getDist(hitPos + rd * h);
		if (d < MIN_DIST){
			return 0.0;
		}
		h += d;
	}
	return 1.0;
}

// O(1): Lighting calculation.
// hitPos: hit position
// rd: ray direction
vec3 getLight(vec3 hitPos, vec3 rd){ // Lighting calculation
	vec3 normals = getNorm(hitPos);
	vec3 lightDir = normalize(hitPos - lightPos);
	float direct = max(-dot(lightDir, normals), 0.0);
	
	vec3 refRd = reflect(rd, normals);
	float reflected = max(-dot(lightDir, refRd), 0.0);

	float lightIntensity = 0.3;

	reflected = pow(reflected, 100);
	vec3 ambient = vec3(0.5);
	float occ = getAmbientOcclusion(hitPos, normals);
	float shadow = getShadow(hitPos, -lightDir);
	vec3 col = vec3(direct + reflected) * lightIntensity * shadow + ambient * occ;
	return col;
}

// O(1): Camera matrix calculation.
// ro: ray origin
// ta: target point
mat3 getCameraMatrix(vec3 ro, vec3 ta){
	vec3 a = normalize(ta - ro);
	vec3 b = cross(a, vec3(0.0, 1.0, 0.0));
	vec3 c = cross(b, a);
	return mat3(b, c, a);
}