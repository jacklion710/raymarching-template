// Forward declaration (the full scene SDF is defined in the main fragment source).
float getDist(vec3 pos);

vec3 getNorm(vec3 hitPos){ // Normal calculation for lighting
	vec2 eps = vec2(0.00001, 0.0);
	float shiftX = getDist(hitPos + eps.xyy) - getDist(hitPos - eps.xyy);
	float shiftY = getDist(hitPos + eps.yxy) - getDist(hitPos - eps.yxy);
	float shiftZ = getDist(hitPos + eps.yyx) - getDist(hitPos - eps.yyx);
	return normalize(vec3(shiftX, shiftY, shiftZ));
}

vec3 getLight(vec3 hitPos, vec3 rd){ // Lighting calculation
	vec3 normals = getNorm(hitPos);
	vec3 lightDir = normalize(hitPos - lightPos);
	float direct = max(-dot(lightDir, normals), 0.0);
	
	vec3 refRd = reflect(rd, normals);
	float reflected = max(-dot(lightDir, refRd), 0.0);

	reflected = pow(reflected, 100);

	vec3 ambient = vec3(0.1);
	vec3 col = vec3(direct + reflected) + ambient;
	return col;
}

mat3 getCameraMatrix(vec3 ro, vec3 ta){
	vec3 a = normalize(ta - ro);
	vec3 b = cross(a, vec3(0.0, 1.0, 0.0));
	vec3 c = cross(b, a);
	return mat3(b, c, a);
}