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

vec3 showcaseBackground(vec3 rd, vec3 ro, vec2 uv);
vec3 causticBackground(vec3 rd, vec3 ro, vec2 uv);
vec3 sssDemoBackground(vec3 rd, vec3 ro, vec2 uv);

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
#endif
}

// Scene-specific background selection (used for fog/reflections/refraction).
vec3 getBackground(vec3 rd, vec3 ro, vec2 uv) {
#if RM_ACTIVE_SCENE == SCENE_SHOWCASE
	return showcaseBackground(rd, ro, uv);
#elif RM_ACTIVE_SCENE == SCENE_CAUSTICS
	return causticBackground(rd, ro, uv);
#elif RM_ACTIVE_SCENE == SCENE_SSS_DEMO
	return sssDemoBackground(rd, ro, uv);
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
