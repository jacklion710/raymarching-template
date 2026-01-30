// Shared globals for the fragment program.
// Keep this file free of #version. It is injected by JXS includes.

#ifndef RM_GLOBALS_GLSL
#define RM_GLOBALS_GLSL

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

// Shared uniforms (declared early so other include files can reference them)
uniform float iTime;
uniform vec2 iResolution;
uniform vec3 lightPos;
uniform vec3 camPos;
uniform float farClip, nearClip;

#endif
