// Forward declaration (the full scene SDF is defined in the main fragment source).
// Returns vec4(albedoRGB, distance).
vec4 getDist(vec3 pos);

// Forward declaration (implemented in marching-engine.glsl, included later).
// Returns vec4(albedoRGB, distanceAlongRay).
vec4 map(vec3 ro, vec3 rd);

// Forward declarations for scene-specific lighting functions
// Each scene file defines its own lighting setup
vec3 showcaseSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate);
vec3 causticSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate);

// Scene lights dispatcher
// Scene selection controlled by RM_ACTIVE_SCENE in globals.glsl
// hitPos: surface hit position
// normals: surface normal
// rd: view ray direction
// mate: surface albedo
vec3 getSceneLights(vec3 hitPos, vec3 normals, vec3 rd, vec3 mate) {
#if RM_ACTIVE_SCENE == SCENE_SHOWCASE
	return showcaseSceneLights(hitPos, normals, rd, mate);
#elif RM_ACTIVE_SCENE == SCENE_CAUSTICS
	return causticSceneLights(hitPos, normals, rd, mate);
#endif
}

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
#if RM_ENABLE_AMBIENT_OCCLUSION
	float occ = 0.0;
	float sca = 1.0;
	for(int i = 0; i < 5; i++){
		float h = 0.01 + 0.04 * float(i) / 4.0;
		float d = getDist(hitPos + normal * h).w;
		// Emissive and transmissive objects don't contribute to occlusion
		float hitEmission = length(gMaterial.emission);
		float hitTransmission = gMaterial.transmission;
		if (hitEmission < 0.5 && hitTransmission < 0.5) {
			occ += (h - d) * sca;
		}
		sca *= 0.5;
	}
	return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
#else
	return 1.0;
#endif
}

// O(n): Simple shadow calculation (no caustics).
// hitPos: hit position
// rd: ray direction toward light
// k: shadow softness (higher = softer penumbra)
float getSimpleShadow(vec3 hitPos, vec3 rd, float k){
	float sha = 1.0;
	for (float h = 0.01; h < 12.0; ){
		float d = getDist(hitPos + rd * h).w;
		float hitEmission = length(gMaterial.emission);
		
		if (d < MIN_DIST){
			if (hitEmission > 0.5) {
				h += 0.15;
				continue;
			}
			if (gMaterial.transmission > 0.5) {
				sha *= 0.7;
				h += 0.1;
				continue;
			}
			if (gMaterial.subsurface > 0.5) {
				sha *= 0.5;
				h += 0.08;
				continue;
			}
			return 0.0;
		}
		if (d < 0.1 && hitEmission > 0.5) {
			h += 0.15;
			continue;
		}
		sha = min(sha, k * d / h);
		h += d;
	}
	return sha;
}

// O(n): Colored shadow calculation with caustics and SSS bleeding.
// hitPos: hit position
// rd: ray direction toward light
// k: shadow softness (higher = softer penumbra)
// Returns: RGB shadow color (white = no shadow, tinted = colored caustic)
#if RM_ENABLE_CAUSTIC_SHADOWS
vec3 getColoredShadow(vec3 hitPos, vec3 rd, float k){
	vec3 shadowColor = vec3(1.0);
	float sha = 1.0;
	float causticBrightness = 1.0;
	
	for (float h = 0.01; h < 12.0; ){
		vec3 samplePos = hitPos + rd * h;
		float d = getDist(samplePos).w;
		float hitEmission = length(gMaterial.emission);
		float hitTransmission = gMaterial.transmission;
		float hitSubsurface = gMaterial.subsurface;
		vec3 hitAlbedo = gMaterial.albedo;
		vec3 hitSubsurfaceCol = gMaterial.subsurfaceCol;
		float hitIridescence = gMaterial.iridescence;
		float hitIOR = gMaterial.ior;
		
		if (d < MIN_DIST){
			// Emissive objects don't block light - step past them
			if (hitEmission > 0.5) {
				h += 0.15;
				continue;
			}
			
			// Transmissive objects cast colored caustic shadows with light focusing
			if (hitTransmission > 0.3) {
				// Get surface normal for refraction/focusing calculation
				vec3 hitNormal = getNorm(samplePos);
				
				// Light focusing from curved surfaces (caustic brightening)
				float curvature = abs(dot(hitNormal, rd));
				float focusing = 1.0 + (1.0 - curvature) * 0.8 * hitTransmission;
				causticBrightness *= focusing;
				
				// Strong absorption-based coloring (Beer-Lambert)
				vec3 absorptionCoeff = vec3(1.0) - hitAlbedo;
				float thickness = 0.25 * (hitIOR - 1.0);
				vec3 causticTint = exp(-absorptionCoeff * thickness * 5.0);
				shadowColor *= causticTint;
				
				// Stronger chromatic aberration
				float chromatic = (hitIOR - 1.33) * 0.2;
				shadowColor.r *= 1.0 + chromatic;
				shadowColor.b *= 1.0 - chromatic;
				
				sha *= mix(1.0, 0.85, hitTransmission);
				h += 0.06;
				continue;
			}
			
			// SSS objects cast colored, soft-edged shadows with depth-based bleeding
			if (hitSubsurface > 0.3) {
				// Sample through the SSS object to estimate thickness
				float sssThickness = 0.0;
				vec3 sssPos = samplePos;
				for (int i = 0; i < 12; i++) {
					float sssD = getDist(sssPos).w;
					if (sssD > MIN_DIST * 2.0) break;
					sssThickness += 0.02;
					sssPos += rd * 0.02;
				}
				
				// Strong color bleeding - the subsurface color dominates
				vec3 absorptionCoeff = vec3(1.0) - hitSubsurfaceCol;
				vec3 sssTint = exp(-absorptionCoeff * sssThickness * 12.0);
				shadowColor *= hitSubsurfaceCol * sssTint * 1.2;
				
				// Very soft shadow - SSS materials let a lot of light through
				sha *= mix(0.5, 0.85, clamp(sssThickness * 8.0, 0.0, 1.0));
				h += sssThickness + 0.02;
				continue;
			}
			
			// Iridescent objects cast rainbow caustic shadows
			if (hitIridescence > 0.3) {
				// Position and angle dependent rainbow
				float phase = dot(samplePos, vec3(1.0, 0.5, 0.3)) * 12.0 + h * 3.0;
				vec3 iriTint = 0.5 + 0.5 * cos(6.28318 * (phase + vec3(0.0, 0.33, 0.67)));
				shadowColor *= mix(vec3(0.8), iriTint, hitIridescence * 0.7);
				sha *= 0.6;
				h += 0.08;
				continue;
			}
			
			// Opaque object - full shadow
			return vec3(0.0);
		}
		
		// Early emissive check during approach
		if (d < 0.1 && hitEmission > 0.5) {
			h += 0.15;
			continue;
		}
		
		sha = min(sha, k * d / h);
		h += d;
	}
	
	// Apply shadow intensity and caustic brightness to color
	return shadowColor * sha * min(causticBrightness, 1.5);
}
#endif

// O(n): Shadow calculation with soft penumbra (intensity only).
// hitPos: hit position
// rd: ray direction toward light
// k: shadow softness (higher = softer penumbra)
float getShadow(vec3 hitPos, vec3 rd, float k){
#if RM_ENABLE_CAUSTIC_SHADOWS
	vec3 coloredShadow = getColoredShadow(hitPos, rd, k);
	return (coloredShadow.r + coloredShadow.g + coloredShadow.b) / 3.0;
#else
	return getSimpleShadow(hitPos, rd, k);
#endif
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
#if RM_ENABLE_CAUSTIC_SHADOWS
	vec3 shadowColor = getColoredShadow(hitPos, -lightDir, shadowSoftness);
#else
	vec3 shadowColor = vec3(getSimpleShadow(hitPos, -lightDir, shadowSoftness));
#endif
	float dist = length(hitPos - lightPos);
	float att = 1. / (dist * dist);

	return (dif * mate + spe * specColor) * shadowColor * att * lightCol;
}

// O(1): Spotlight calculation (cone-shaped directional light)
// hitPos: surface position
// spotPos: spotlight position
// spotDir: spotlight direction (normalized)
// normals: surface normal
// rd: view ray direction
// spotCol: light color and intensity
// innerAngle: inner cone angle in radians (full intensity)
// outerAngle: outer cone angle in radians (falloff edge)
vec3 getSpotLight(vec3 hitPos, vec3 spotPos, vec3 spotDir, vec3 normals, vec3 rd, vec3 spotCol, float innerAngle, float outerAngle) {
	float metallic = gMaterial.metallic;
	float roughness = gMaterial.roughness;
	vec3 mate = gMaterial.albedo;
	
	vec3 toLight = spotPos - hitPos;
	float dist = length(toLight);
	vec3 lightDir = toLight / dist;
	
	// Cone attenuation: check angle between light direction and spotlight direction
	float cosAngle = dot(-lightDir, spotDir);
	float cosInner = cos(innerAngle);
	float cosOuter = cos(outerAngle);
	float spotAtt = clamp((cosAngle - cosOuter) / (cosInner - cosOuter), 0.0, 1.0);
	spotAtt = spotAtt * spotAtt;  // Smooth falloff
	
	if (spotAtt <= 0.0) return vec3(0.0);  // Outside cone
	
	// Diffuse
	float NdotL = max(dot(normals, lightDir), 0.0);
	vec3 diffuse = mate * NdotL * (1.0 - metallic * 0.9);
	
	// Specular
	vec3 halfVec = normalize(lightDir - rd);
	float NdotH = max(dot(normals, halfVec), 0.0);
	float specPower = mix(64.0, 4.0, roughness);
	float spec = pow(NdotH, specPower);
	vec3 specColor = mix(vec3(0.5), mate, metallic);
	vec3 specular = specColor * spec;
	
	// Distance attenuation
	float distAtt = 1.0 / (1.0 + dist * dist * 2.0);
	
	// Shadow calculation
#if RM_ENABLE_CAUSTIC_SHADOWS
	vec3 shadowColor = getColoredShadow(hitPos, lightDir, 8.0);
#else
	vec3 shadowColor = vec3(getSimpleShadow(hitPos, lightDir, 8.0));
#endif
	
	return (diffuse + specular) * spotAtt * distAtt * shadowColor * spotCol;
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
	float subsurface = gMaterial.subsurface;
	vec3 subsurfaceCol = gMaterial.subsurfaceCol;
	float toonSteps = gMaterial.toonSteps;

#if !RM_ENABLE_IRIDESCENCE
	iridescence = 0.0;
#endif
	
	// Apply iridescence if present (view-dependent color shift)
#if RM_ENABLE_IRIDESCENCE
	if (iridescence > 0.0) {
		float NdotV = max(dot(normals, -rd), 0.0);
		vec3 iriColor = getIridescentColor(NdotV, mate);
		mate = mix(mate, iriColor, iridescence);
	}
#endif
	
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

#if RM_ENABLE_TOON
	if (toonSteps > 0.0) {
		float steps = max(toonSteps, 1.0);
		float toonDiffuse = floor(NdotL * steps) / steps;
		float toonSpec = step(0.75, spec);
		diffuse = mate * toonDiffuse * (1.0 - metallic * 0.9);
		specular = specColor * toonSpec;
	}
#endif
	
	// Emissive strength calculation (used for shadow and AO adjustments)
	float emissionStrength = clamp(length(gMaterial.emission) / 3.0, 0.0, 1.0);
	
	// Toon materials: hard shadows and no AO for clean cartoon look
	float occ = 1.0;
	float shadowSoftness = mix(16.0, 4.0, roughness);
#if RM_ENABLE_TOON
	if (toonSteps > 0.0) {
		shadowSoftness = 32.0;  // Hard shadow edges
	} else {
		occ = getAmbientOcclusion(hitPos, normals);
	}
#else
	occ = getAmbientOcclusion(hitPos, normals);
#endif
	
	// Shadow calculation (colored caustics when enabled)
#if RM_ENABLE_CAUSTIC_SHADOWS
	vec3 shadowColor = getColoredShadow(hitPos, -lightDir, shadowSoftness);
#else
	vec3 shadowColor = vec3(getSimpleShadow(hitPos, -lightDir, shadowSoftness));
#endif
	
	// Emissive objects don't receive shadows (they glow uniformly)
	shadowColor = mix(shadowColor, vec3(1.0), emissionStrength);
	
	vec3 ambient = vec3(0.1) * mate * occ;  // Ambient for visibility
	
	float lightIntensity = 0.28;  // Main light intensity
	vec3 col = (diffuse + specular) * lightIntensity * shadowColor + ambient;
	
	// Subsurface scattering: light penetrating and scattering inside the material
#if RM_ENABLE_SSS
	if (subsurface > 0.0) {
		// Estimate thickness by sampling SDF behind the surface
		float thickness = 0.0;
		vec3 sampleDir = -normals;
		for (int i = 1; i <= 4; i++) {
			float sampleDist = 0.02 * float(i);
			float d = getDist(hitPos + sampleDir * sampleDist).w;
			thickness += max(0.0, -d);
		}
		thickness = clamp(thickness * 4.0, 0.0, 1.0);
		
		// Absorption: thicker areas absorb more light (Beer-Lambert)
		// Absorb wavelengths that are NOT the subsurface color
		vec3 absorptionCoeff = vec3(1.0) - subsurfaceCol;
		vec3 absorption = exp(-absorptionCoeff * thickness * 4.0);
		
		// Reduce and tint surface lighting - light penetrates instead of bouncing
		float surfaceReduction = mix(1.0, 0.3, subsurface);
		col *= surfaceReduction * absorption;
		
		// Back-lighting: light shining through from behind
		float NdotL_back = max(dot(lightDir, normals), 0.0);
		float backlit = NdotL_back * pow(1.0 - thickness, 2.0);
		
		// Wrap lighting for soft light bleeding around edges
		float wrap = max(0.0, (dot(-lightDir, normals) + 0.5) / 1.5);
		
		// View-dependent rim scattering
		float NdotV = max(dot(normals, -rd), 0.0);
		float rimScatter = pow(1.0 - NdotV, 3.0) * 0.3;
		
		// Combine scattering terms - thin areas glow more
		float scatter = (wrap * 0.5 + backlit * 1.5 + rimScatter) * (1.0 - thickness * 0.7);
		
		// Final SSS color - the subsurface color shows through
		vec3 sssColor = subsurfaceCol * scatter * subsurface * lightIntensity;
		col += sssColor;
	}
#endif

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
	// Skip emissive lighting for surfaces that are themselves emissive
#if RM_ENABLE_EMISSIVE
	if (emissionStrength < 0.5) {
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
	}
#endif
	
	// Scene-specific lights (spotlights, point lights)
	// Each scene defines its own lighting setup in getSceneLights()
	col += getSceneLights(hitPos, normals, rd, mate);
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