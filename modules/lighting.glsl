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

// O(n): Ambient occlusion calculation.
// hitPos: hit position
// normal: normal vector
float getAmbientOcclusion(vec3 hitPos, vec3 normal){
	float occ = 0.0;
	float sca = 1.0;
	for(int i = 0; i < 5; i++){
		float h = 0.01 + 0.04 * float(i) / 4.0;
		float d = getDist(hitPos + normal * h).w;
		// Emissive objects don't contribute to occlusion (they emit light)
		if (length(gMaterial.emission) < 1.0) {
			occ += (h - d) * sca;
		}
		sca *= 0.5;
	}
	return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

// O(n): Shadow calculation with soft penumbra.
// hitPos: hit position
// rd: ray direction toward light
// k: shadow softness (higher = softer penumbra)
float getShadow(vec3 hitPos, vec3 rd, float k){
	float sha = 1.0;
	for (float h = 0.01; h < 12.0; ){
		float d = getDist(hitPos + rd * h).w;
		if (d < MIN_DIST){
			// Emissive objects don't block light - step past them
			if (length(gMaterial.emission) > 1.0) {
				h += 0.15;
				continue;
			}
			return 0.0;
		}
		// Early emissive check during approach
		if (d < 0.1 && length(gMaterial.emission) > 1.0) {
			h += 0.15;
			continue;
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
	
	float metallic = gMaterial.metallic;
	float roughness = gMaterial.roughness;
	
	vec3 lightDir = normalize(hitPos - lightPos);
	vec3 halfVec = normalize(-lightDir - rd);
	
	// Diffuse - metals have reduced diffuse
	float dif = max(-dot(lightDir, normals), 0.) * (1.0 - metallic * 0.9);
	
	// Specular
	float NdotH = max(dot(normals, halfVec), 0.);
	float specPower = mix(64.0, 4.0, roughness);
	float spe = pow(NdotH, specPower);
	vec3 specColor = mix(vec3(0.5), mate, metallic);
	
	// Softer shadows for rough surfaces (higher k = softer)
	float shadowSoftness = mix(17.0, 4.0, roughness);
	float sha = getShadow(hitPos, -lightDir, shadowSoftness);
	float dist = length(hitPos - lightPos);
	float att = 1. / (dist * dist);

	return (dif * mate + spe * specColor) * sha * att * lightCol;
}

// O(1): Sky light calculation.
// normals: normal vector
vec3 getSkyLight(vec3 hitPos, vec3 normals, float occ, vec3 mate, vec3 refRd, vec3 col){
	float roughness = gMaterial.roughness;
	
	float dif = sqrt(clamp(normals.y * 0.5 + 0.5, 0.0, 1.0));
	float fresnel = pow(clamp(1. - dot(normals, -refRd), 0., 1.), 5.) * 0.95 + 0.05;
	vec3 skyCol = vec3(0.7, .9, 1.0)*0.4;
	col += dif * skyCol * occ * mate * (1.0 - fresnel);
	
	// Sky specular - skip reflection shadow for rough surfaces
	float spe = smoothstep(-0.2, 0.2, refRd.y);
	if (roughness < 0.5) {
		spe *= getShadow(hitPos, refRd, 0.5);
	}
	// Reduce sky specular for rough surfaces
	spe *= (1.0 - roughness);
	col += spe * skyCol * occ * fresnel;
	return col;
}

// O(1): Lighting calculation with PBR metallic support.
// hitPos: hit position
// rd: ray direction
// mate: albedo color (legacy parameter, also available via gMaterial)
// normals: surface normal
vec3 getLight(vec3 hitPos, vec3 rd, vec3 mate, vec3 normals){
	
	// Get material properties
	float metallic = gMaterial.metallic;
	float roughness = gMaterial.roughness;
	float iridescence = gMaterial.iridescence;
	
	// Apply iridescence if present (view-dependent color shift)
	if (iridescence > 0.0) {
		float NdotV = max(dot(normals, -rd), 0.0);
		vec3 iriColor = getIridescentColor(NdotV, mate);
		mate = mix(mate, iriColor, iridescence);
	}
	
	// Base vectors
	vec3 lightDir = normalize(hitPos - lightPos);
	vec3 refRd = reflect(rd, normals);
	vec3 halfVec = normalize(-lightDir - rd);
	
	// Diffuse: metals have reduced diffuse
	float NdotL = max(-dot(lightDir, normals), 0.0);
	vec3 diffuse = mate * NdotL * (1.0 - metallic * 0.9);
	
	// Specular: roughness controls sharpness
	float NdotH = max(dot(normals, halfVec), 0.0);
	float specPower = mix(64.0, 4.0, roughness);
	float spec = pow(NdotH, specPower);
	// Metals tint specular with albedo, dielectrics have white specular
	// For iridescent materials, tint specular with the shifted color
	vec3 specColor = mix(vec3(0.5), mate, max(metallic, iridescence * 0.5));
	vec3 specular = specColor * spec;
	
	// Environment/ambient - softer shadows for rough surfaces
	float occ = getAmbientOcclusion(hitPos, normals);
	float shadowSoftness = mix(16.0, 4.0, roughness);
	float shadow = getShadow(hitPos, -lightDir, shadowSoftness);
	
	// Emissive objects cast weaker shadows (their own light fills the shadow area)
	float emissionStrength = clamp(length(gMaterial.emission) / 3.0, 0.0, 1.0);
	shadow = mix(shadow, 1.0, emissionStrength);
	
	vec3 ambient = vec3(0.3) * mate * occ;
	
	float lightIntensity = 0.8;
	vec3 col = (diffuse + specular) * lightIntensity * shadow + ambient;

#if USE_POINT_LIGHT
	// {   // Sky light
	// 	col += getSkyLight(hitPos, normals, occ, mate, refRd, col);
	// }

	// {   // Point light
	// 	vec3 pointPos = vec3(0.5, 0.4, 0.2);
	// 	vec3 pointCol = vec3(1.0, 0.9, 0.8) * 1.0;
	// 	col += getPointLight(hitPos, pointPos, normals, rd, refRd, pointCol, mate);
	// }
	
	// Emissive area lights (loops through all centralized emissive definitions)
	for (int i = 0; i < NUM_EMISSIVES; i++) {
		vec4 source = getEmissiveSource(i);
		vec4 props = getEmissiveProperties(i);
		
		vec3 emissivePos = source.xyz;
		float emissiveRadius = source.w;
		vec3 emissiveCol = props.xyz;
		float emissivePower = props.w;
		
		vec3 toEmissive = emissivePos - hitPos;
		float distToEmissive = length(toEmissive);
		vec3 emissiveDir = toEmissive / max(distToEmissive, 0.001);
		
		// Wrap lighting for soft diffuse spread
		float emissiveDiffuse = max(dot(normals, emissiveDir) * 0.5 + 0.5, 0.0);
		
		// Smooth falloff starting from sphere surface
		float effectiveDist = max(distToEmissive - emissiveRadius, 0.001);
		float emissiveAtt = 1.0 / (1.0 + effectiveDist * effectiveDist * 5.0);
		
		// Smoothly fade out when very close to emissive (on its surface)
		float surfaceFade = smoothstep(emissiveRadius, emissiveRadius * 3.0, distToEmissive);
		
		col += emissiveDiffuse * emissiveAtt * surfaceFade * emissiveCol * mate * emissivePower;
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
		// Save emission before getLight overwrites gMaterial
		vec3 emission = gMaterial.emission;
		float emissionStrength = clamp(length(emission) / 3.0, 0.0, 1.0);
		
		vec3 normals = getNorm(hitPos);
		// Reduce lighting for emissive objects (they glow uniformly)
		vec3 lighting = getLight(hitPos, rd, material, normals) * (1.0 - emissionStrength);
		return lighting + emission;
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