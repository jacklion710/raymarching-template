// Scene result: holds distance and material together
struct SceneResult {
	float dist;
	Material mat;
};

// Helper to create a SceneResult
SceneResult sceneResult(float dist, Material mat) {
	return SceneResult(dist, mat);
}

// Combine two scene results, keeping the closer one
SceneResult sceneMin(SceneResult a, SceneResult b) {
	return (a.dist < b.dist) ? a : b;
}

// Smooth minimum blend of two scene results
SceneResult sceneSmin(SceneResult a, SceneResult b, float k) {
	float h = clamp(0.5 + 0.5 * (b.dist - a.dist) / k, 0.0, 1.0);
	float dist = mix(b.dist, a.dist, h) - k * h * (1.0 - h);
	Material mat = mixMaterial(b.mat, a.mat, h);
	return SceneResult(dist, mat);
}

// Scene function forward declarations
// Each scene file (e.g., scenes/showcase.glsl) defines its own scene function
vec4 showcaseScene(vec3 pos);
vec4 causticScene(vec3 pos);
vec4 sssDemoScene(vec3 pos);
vec4 envMapScene(vec3 pos);
vec4 hgSdfModifiersScene(vec3 pos);
vec4 iridescenceShowcaseScene(vec3 pos);
vec4 nightLightsScene(vec3 pos);
vec4 paletteConcertScene(vec3 pos);
vec4 optimizationTestScene(vec3 pos);
vec4 edgeGlowHaloScene(vec3 pos);

// Scene background forward declarations
// Backgrounds are evaluated in "sky UV" derived from the view ray direction.
vec3 showcaseBackground(vec2 skyUV, vec3 rd, vec3 ro);
vec3 causticBackground(vec2 skyUV, vec3 rd, vec3 ro);
vec3 sssDemoBackground(vec2 skyUV, vec3 rd, vec3 ro);
vec3 envMapBackground(vec2 skyUV, vec3 rd, vec3 ro);
vec3 hgSdfModifiersBackground(vec2 skyUV, vec3 rd, vec3 ro);
vec3 iridescenceShowcaseBackground(vec2 skyUV, vec3 rd, vec3 ro);
vec3 nightLightsBackground(vec2 skyUV, vec3 rd, vec3 ro);
vec3 paletteConcertBackground(vec2 skyUV, vec3 rd, vec3 ro);
vec3 optimizationTestBackground(vec2 skyUV, vec3 rd, vec3 ro);
vec3 edgeGlowHaloBackground(vec2 skyUV, vec3 rd, vec3 ro);

// O(1): Get the distance bound to the nearest surface in the scene.
// pos: world-space position being sampled
// Scene selection controlled by RM_ACTIVE_SCENE in globals.glsl
vec4 getDist(vec3 pos) {
#if RM_ACTIVE_SCENE == SCENE_SHOWCASE
	return showcaseScene(pos);
#elif RM_ACTIVE_SCENE == SCENE_CAUSTICS
	return causticScene(pos);
#elif RM_ACTIVE_SCENE == SCENE_SSS_DEMO
	return sssDemoScene(pos);
#elif RM_ACTIVE_SCENE == SCENE_ENV_MAP
	return envMapScene(pos);
#elif RM_ACTIVE_SCENE == SCENE_HG_SDF_MODIFIERS
	return hgSdfModifiersScene(pos);
#elif RM_ACTIVE_SCENE == SCENE_IRIDESCENCE_SHOWCASE
	return iridescenceShowcaseScene(pos);
#elif RM_ACTIVE_SCENE == SCENE_NIGHT_LIGHTS
	return nightLightsScene(pos);
#elif RM_ACTIVE_SCENE == SCENE_PALETTE_CONCERT
	return paletteConcertScene(pos);
#elif RM_ACTIVE_SCENE == SCENE_OPTIMIZATION_TEST
	return optimizationTestScene(pos);
#elif RM_ACTIVE_SCENE == SCENE_EDGE_GLOW_HALO
	return edgeGlowHaloScene(pos);
#endif
}

// Scene-specific background selection (used for fog/reflections/refraction).
// NOTE: Backgrounds are intended to be authored in sky-space (not screen-space).
vec3 getBackground(vec3 rd, vec3 ro) {
	vec2 skyUV = rmSkyUV(rd);
#if RM_ACTIVE_SCENE == SCENE_SHOWCASE
	return showcaseBackground(skyUV, rd, ro);
#elif RM_ACTIVE_SCENE == SCENE_CAUSTICS
	return causticBackground(skyUV, rd, ro);
#elif RM_ACTIVE_SCENE == SCENE_SSS_DEMO
	return sssDemoBackground(skyUV, rd, ro);
#elif RM_ACTIVE_SCENE == SCENE_ENV_MAP
	return envMapBackground(skyUV, rd, ro);
#elif RM_ACTIVE_SCENE == SCENE_HG_SDF_MODIFIERS
	return hgSdfModifiersBackground(skyUV, rd, ro);
#elif RM_ACTIVE_SCENE == SCENE_IRIDESCENCE_SHOWCASE
	return iridescenceShowcaseBackground(skyUV, rd, ro);
#elif RM_ACTIVE_SCENE == SCENE_NIGHT_LIGHTS
	return nightLightsBackground(skyUV, rd, ro);
#elif RM_ACTIVE_SCENE == SCENE_PALETTE_CONCERT
	return paletteConcertBackground(skyUV, rd, ro);
#elif RM_ACTIVE_SCENE == SCENE_OPTIMIZATION_TEST
	return optimizationTestBackground(skyUV, rd, ro);
#elif RM_ACTIVE_SCENE == SCENE_EDGE_GLOW_HALO
	return edgeGlowHaloBackground(skyUV, rd, ro);
#endif
}

// O(n): Raymarching loop.
// ro: ray origin
// rd: ray direction
vec4 map(vec3 ro, vec3 rd){
	float hitMap;
	float currDist = nearClip;
	float dist = 0; 
	vec4 scene;
	vec3 pos;
	float minDist = MIN_DIST;
	int maxSteps = MAX_STEPS;
#if RM_ENABLE_LOD
	float mid = farClip * RM_LOD_MID_RATIO;
	float far = farClip * RM_LOD_FAR_RATIO;
#endif
	
	for(int i = 0; i < MAX_STEPS; i++) {
	#if RM_ENABLE_LOD
		if (currDist > far) {
			minDist = MIN_DIST * RM_LOD_MIN_DIST_SCALE_FAR;
			maxSteps = int(float(MAX_STEPS) * RM_LOD_MAX_STEPS_SCALE_FAR);
		} else if (currDist > mid) {
			minDist = MIN_DIST * RM_LOD_MIN_DIST_SCALE_MID;
			maxSteps = int(float(MAX_STEPS) * RM_LOD_MAX_STEPS_SCALE_MID);
		}
		if (i >= maxSteps) {
			break;
		}
	#endif
		pos = ro + rd * currDist;
		scene = getDist(pos);
		dist = scene.w;
		currDist += dist * rmGetStepScale(currDist);
		hitMap = i / MAX_STEPS - 1.0;
		if(abs(dist) < minDist || currDist > farClip){
			break;
		}
	}
	return vec4(scene.rgb, currDist);
}
