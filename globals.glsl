// Shared globals for the fragment program.
// Keep this file free of #version. It is injected by JXS includes.

#ifndef RM_GLOBALS_GLSL
#define RM_GLOBALS_GLSL

// Raymarch settings
#ifndef MAX_STEPS
#define MAX_STEPS 100
#endif

#ifndef MIN_DIST
#define MIN_DIST 0.0001
#endif

#ifndef MAX_DIST
#define MAX_DIST 100.0
#endif

// Shared uniforms (declared early so other include files can reference them)
uniform float iTime;
uniform vec2 iResolution;
uniform vec3 lightPos;
uniform vec3 camPos;

#endif
