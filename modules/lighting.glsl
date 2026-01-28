// Forward declaration (the full scene SDF is defined in the main fragment source).
// Returns vec4(albedoRGB, distance).
vec4 getDist(vec3 pos);

// Forward declaration (implemented in marching-engine.glsl, included later).
// Returns vec4(albedoRGB, distanceAlongRay).
vec4 map(vec3 ro, vec3 rd);

// O(1): Normal calculation for lighting.
// hitPos: hit position
vec3 getNorm(vec3 hitPos){ // Normal calculation for lighting
	vec2 eps = vec2(0.00001, 0.0);
	float shiftX = getDist(hitPos + eps.xyy).w - getDist(hitPos - eps.xyy).w;
	float shiftY = getDist(hitPos + eps.yxy).w - getDist(hitPos - eps.yxy).w;
	float shiftZ = getDist(hitPos + eps.yyx).w - getDist(hitPos - eps.yyx).w;
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
		float d = getDist(hitPos + normal * h).w;
		occ += (h - d) * sca;
		sca *= 0.5;
	}
	return clamp(1.0 - 6.0 * occ, 0.0, 1.0);
}

// O(1): Shadow calculation.
// hitPos: hit position
// rd: ray direction
float getShadow(vec3 hitPos, vec3 rd, float k){
	float sha = 1.;
	for (float h = 0.01; h < 12.0; ){
		float d = getDist(hitPos + rd * h).w;
		if (d < MIN_DIST){
			return 0.0;
		}
		sha = min(sha, k * d / h);
		h += d;
	}
	return sha;
}

// Optional point light toggle (no external parameters for now).
#ifndef USE_POINT_LIGHT
#define USE_POINT_LIGHT 1
#endif

vec3 getPointLight(vec3 hitPos, vec3 lightPos, vec3 normals, vec3 rd, vec3 refRd, vec3 lightCol, vec3 mate){
	
	vec3 	lightDir 	= normalize(hitPos - lightPos);
	vec3  	halfVec 	= normalize(lightDir - rd);
	float 	dif 		= max(-dot(lightDir, normals), 0.);
	float 	spe 		= max(-dot(lightDir, refRd), 0.);
			spe 		= pow(spe, 100);
	float 	sha 		= getShadow(hitPos, -lightDir, 17);
	float 	dist 		= length(hitPos - lightPos);
	float   att 		= 1. / (dist*dist);
	float 	fresnel 	= pow(clamp(1. - dot(halfVec, lightDir), 0., 1.), 5.) * 0.95 + 0.05;

	return  vec3(mix(dif, spe, fresnel)) *sha*mate*att*lightCol;
}

// O(1): Sky light calculation.
// normals: normal vector
vec3 getSkyLight(vec3 hitPos, vec3 normals, float occ, vec3 mate, vec3 refRd, vec3 col){
	float dif = sqrt(clamp(normals.y * 0.5 + 0.5, 0.0, 1.0));
	float fresnel = pow(clamp(1. - dot(normals, -refRd), 0., 1.), 5.) * 0.95 + 0.05;
	vec3 skyCol = vec3(0.7, .9, 1.0)*0.4;
	col += dif * skyCol * occ * mate * (1.0 - fresnel);
	float spe = smoothstep(-0.2, 0.2, refRd.y);
	spe *= getShadow(hitPos, refRd, 0.5);
	col += spe * skyCol * occ * fresnel;
	return col;
}

// O(1): Lighting calculation.
// hitPos: hit position
// rd: ray direction
vec3 getLight(vec3 hitPos, vec3 rd, vec3 mate, vec3 normals){ // Lighting calculation
	
	// Base Phong lighting (existing path)
	vec3 lightDir = normalize(hitPos - lightPos);
	float direct = max(-dot(lightDir, normals), 0.0);
	
	vec3 refRd = reflect(rd, normals);
	float reflected = max(-dot(lightDir, refRd), 0.0);

	float lightIntensity = 0.3;

	reflected = pow(reflected, 100.0);
	vec3 ambient = vec3(0.5);
	float occ = getAmbientOcclusion(hitPos, normals);
	float shadow = getShadow(hitPos, -lightDir, 16.0);

	// Apply material albedo here so all light paths behave consistently.
	vec3 col = (vec3(direct + reflected) * lightIntensity * shadow + ambient * occ) * mate;

#if USE_POINT_LIGHT
	// Point light using getPointLight(); mate is set to 1 because albedo is applied outside getLight().
	{   // Sky light
		col += getSkyLight(hitPos, normals, occ, mate, refRd, col);
	}

	{   // Point light
		// Blue point light near the cube (kept outside geometry)
		// Box spans roughly x,z ∈ [-0.1,0.1] and y up to ~0.28, so keep this outside and above.
		vec3 pointPos = vec3(0.35, 0.35, 0.0);
		// Boosted because final shading multiplies by material albedo.
		vec3 pointCol = vec3(0.9, 0.2, 8.0) * 20.0;
		col += getPointLight(hitPos, pointPos, normals, rd, refRd, pointCol, mate);
	}
#endif

	return col;
}

vec3 getFirstReflection(vec3 ro, vec3 rd, vec3 bgCol){
	vec4 scene = map(ro, rd);
	vec3 material = scene.rgb;
	float dist = scene.w;

	// Color the scene based on the distance to the object
	if (dist > farClip){
		return bgCol;
	} else {
		vec3 hitPos = ro + rd * dist;
		vec3 normals = getNorm(hitPos);
		return getLight(hitPos, rd, material, normals);
	}
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