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

// Shared uniforms (declared early so other include files can reference them)
uniform float iTime;
uniform vec2 iResolution;
uniform vec3 lightPos;
uniform vec3 camPos;
uniform float farClip, nearClip;

#endif
