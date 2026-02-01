// Shared globals for the fragment program.
// Keep this file free of #version. It is injected by JXS includes.

#ifndef RM_GLOBALS_GLSL
#define RM_GLOBALS_GLSL

// Scene selection - change this to switch between scenes
// Available scenes: SCENE_SHOWCASE, SCENE_CAUSTICS, SCENE_SSS_DEMO, SCENE_ENV_MAP, SCENE_HG_SDF_MODIFIERS, SCENE_IRIDESCENCE_SHOWCASE, SCENE_NIGHT_LIGHTS, SCENE_PALETTE_CONCERT
#define SCENE_SHOWCASE 0
#define SCENE_CAUSTICS 1
#define SCENE_SSS_DEMO 2
#define SCENE_ENV_MAP 3
#define SCENE_HG_SDF_MODIFIERS 4
#define SCENE_IRIDESCENCE_SHOWCASE 5
#define SCENE_NIGHT_LIGHTS 6
#define SCENE_PALETTE_CONCERT 7

#ifndef RM_ACTIVE_SCENE
#define RM_ACTIVE_SCENE SCENE_PALETTE_CONCERT
#endif

// Raymarch settings
#ifndef MAX_STEPS
#define MAX_STEPS 500
#endif

#ifndef MIN_DIST
#define MIN_DIST 0.0001
#endif

// Feature toggles (0 = off, 1 = on)
#ifndef RM_ENABLE_IRIDESCENCE
#define RM_ENABLE_IRIDESCENCE 1
#endif

#ifndef RM_ENABLE_SSS
#define RM_ENABLE_SSS 1
#endif

#ifndef RM_ENABLE_EMISSIVE
#define RM_ENABLE_EMISSIVE 1
#endif

#ifndef RM_ENABLE_TOON
#define RM_ENABLE_TOON 1
#endif

#ifndef RM_ENABLE_REFRACTION
#define RM_ENABLE_REFRACTION 1
#endif

#ifndef RM_ENABLE_REFLECTIONS
#define RM_ENABLE_REFLECTIONS 1
#endif

#ifndef RM_ENABLE_SPOTLIGHT
#define RM_ENABLE_SPOTLIGHT 1
#endif

#ifndef RM_ENABLE_AMBIENT_OCCLUSION
#define RM_ENABLE_AMBIENT_OCCLUSION 1
#endif

#ifndef RM_ENABLE_CAUSTIC_SHADOWS
#define RM_ENABLE_CAUSTIC_SHADOWS 1
#endif

#ifndef RM_ENABLE_ENV_MAP
#define RM_ENABLE_ENV_MAP 1
#endif

#ifndef RM_ENABLE_GI
#define RM_ENABLE_GI 1
#endif

// LOD system (distance-based quality scaling)
#ifndef RM_ENABLE_LOD
#define RM_ENABLE_LOD 1
#endif

// LOD thresholds as ratios of farClip
#ifndef RM_LOD_MID_RATIO
#define RM_LOD_MID_RATIO 0.35
#endif

#ifndef RM_LOD_FAR_RATIO
#define RM_LOD_FAR_RATIO 0.65
#endif

// LOD quality scales
#ifndef RM_LOD_MIN_DIST_SCALE_MID
#define RM_LOD_MIN_DIST_SCALE_MID 2.5
#endif

#ifndef RM_LOD_MIN_DIST_SCALE_FAR
#define RM_LOD_MIN_DIST_SCALE_FAR 5.0
#endif

#ifndef RM_LOD_MAX_STEPS_SCALE_MID
#define RM_LOD_MAX_STEPS_SCALE_MID 0.6
#endif

#ifndef RM_LOD_MAX_STEPS_SCALE_FAR
#define RM_LOD_MAX_STEPS_SCALE_FAR 0.35
#endif
// Emissive flicker phase offset control (0 = synced, 1 = staggered)
#ifndef RM_EMISSIVE_FLICKER_STAGGER
#define RM_EMISSIVE_FLICKER_STAGGER 1.0
#endif

// Post-processing profiles (0 = filmic look, 1 = neutral/debug)
// Neutral disables most grading so albedo reads "raw".
#define RM_POST_PROFILE_FILMIC 0
#define RM_POST_PROFILE_NEUTRAL 1

#ifndef RM_POST_PROFILE
#define RM_POST_PROFILE RM_POST_PROFILE_FILMIC
#endif

// Shared uniforms (declared early so other include files can reference them)
uniform float iTime;
uniform vec2 iResolution;
uniform vec3 lightPos;
uniform vec3 camPos;
uniform float farClip, nearClip;

float rmGetLodFactor(float dist){
#if RM_ENABLE_LOD
	float mid = farClip * RM_LOD_MID_RATIO;
	float far = farClip * RM_LOD_FAR_RATIO;
	return smoothstep(mid, far, dist);
#else
	return 0.0;
#endif
}

// Per-hit LOD factor (set by shading to drive quality scaling)
float gLodFactor = 0.0;

#endif
