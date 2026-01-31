# Module Reference

Quick reference for all GLSL modules in the template.

## Core Modules

### globals.glsl

**Purpose:** Shared constants, feature flags, and uniform declarations.

**Key definitions:**
```glsl
MAX_STEPS          // Maximum raymarch iterations (500)
MIN_DIST           // Surface hit threshold (0.0001)
RM_ENABLE_*        // Feature flags
RM_ENABLE_GI       // Global illumination toggle

// Uniforms
uniform float iTime;
uniform vec2 iResolution;
uniform vec3 lightPos;
uniform vec3 camPos;
uniform float farClip, nearClip;
```

**Dependencies:** None (must be included first)

---

### materials.glsl

**Purpose:** Material struct, presets, and emissive light definitions.

**Key exports:**
```glsl
struct Material { ... }
Material gMaterial;                    // Global material state

// Iridescence
vec3 getIridescentColor(float viewAngle, vec3 baseColor);

// Emissive sources
vec4 getEmissiveSource(int index);     // position.xyz, radius.w
vec4 getEmissiveProperties(int index); // color.xyz, intensity.w

// Material creation
Material createMaterial(...);          // Multiple overloads
Material mixMaterial(Material a, Material b, float t);

// Presets
Material matPlastic(vec3 color);
Material matMetal(vec3 color);
Material matGold();
Material matRoughMetal(vec3 color);
Material matMirror();
Material matRubber(vec3 color);
Material matGlow(vec3 color, float intensity);
Material matNeon(vec3 color);
Material matLava(vec3 color);
Material matHotMetal(vec3 color);
Material matSoapBubble();
Material matOilSlick();
Material matBeetleShell(vec3 baseColor);
Material matPearl();
Material matWax(vec3 color);
Material matSkin(vec3 color);
Material matJade(vec3 color);
Material matMarble();
Material matGlass();
Material matWater();
Material matCrystal();
Material matToon(vec3 color, float steps);
```

**Dependencies:** globals.glsl

---

### marching-engine.glsl

**Purpose:** Scene composition and raymarching loop.

**Key exports:**
```glsl
struct SceneResult { float dist; Material mat; }

SceneResult sceneResult(float dist, Material mat);
SceneResult sceneMin(SceneResult a, SceneResult b);
SceneResult sceneSmin(SceneResult a, SceneResult b, float k);

vec4 getDist(vec3 pos);  // Scene SDF - EDIT THIS FOR YOUR SCENE
vec4 map(vec3 ro, vec3 rd);  // Raymarching loop
```

**Dependencies:** All SDF modules, materials.glsl

---

### lighting.glsl

**Purpose:** All lighting calculations.

**Key exports:**
```glsl
vec3 getNorm(vec3 hitPos);
float getAmbientOcclusion(vec3 hitPos, vec3 normal);
vec3 getGlobalIllumination(vec3 normals, vec3 mate, float occ);
float getShadow(vec3 hitPos, vec3 rd, float k);
vec3 getColoredShadow(vec3 hitPos, vec3 rd, float k);
float getSimpleShadow(vec3 hitPos, vec3 rd, float k);

vec3 getPointLight(vec3 hitPos, vec3 lightPos, vec3 normals, 
                   vec3 rd, vec3 refRd, vec3 lightCol, vec3 mate);
vec3 getSpotLight(vec3 hitPos, vec3 spotPos, vec3 spotDir, 
                  vec3 normals, vec3 rd, vec3 spotCol, 
                  float innerAngle, float outerAngle);
vec3 getSkyLight(vec3 hitPos, vec3 normals, float occ, 
                 vec3 mate, vec3 refRd, vec3 col);
vec3 getLight(vec3 hitPos, vec3 rd, vec3 mate, vec3 normals);
vec3 getFirstReflection(vec3 ro, vec3 rd, vec3 bgCol);

mat3 getCameraMatrix(vec3 ro, vec3 ta);
```

**Dependencies:** materials.glsl, SDF modules

---

### camera.glsl

**Purpose:** Camera setup, DoF, and surface shading entry point.

**Key exports:**
```glsl
struct DoFConfig { ... }
DoFConfig getDefaultDoFConfig();
float polygonRadius(float angle, float blades, float rotation);
vec3 getDoFOffset(int sampleIndex, int sampleCount, mat3 camMat, 
                  DoFConfig config, float time);

// Refraction
float estimateTransmissionThickness(vec3 startPos, vec3 dir);
void marchThroughObject(vec3 ro, vec3 rd, float ior, 
                        out vec3 exitPos, out vec3 exitNormal, out float thickness);
vec3 traceRefraction(vec3 hitPos, vec3 rd, vec3 normal, 
                     float ior, vec3 tint, vec3 bgCol);

// Main shading function
vec3 shadeHit(vec3 hitPos, vec3 rd, vec3 material, vec3 bgCol);

vec3 getLensFlare(vec3 rd, vec3 ro, vec3 lightPos, vec3 lightCol, float expo);
```

**Dependencies:** lighting.glsl

---

### post.glsl

**Purpose:** Post-processing effects.

**Key exports:**
```glsl
void getPostProcessing(inout vec3 col, vec3 rd, vec3 ro, 
                       vec3 bgCol, float dist, vec2 uv);
```

**Dependencies:** color.glsl, camera.glsl

---

## Utility Modules

### sdf.glsl

**Purpose:** Basic SDF primitives (custom).

**Key exports:**
```glsl
float SDFbox(vec3 p, vec3 c, vec3 ra);
float SDFsphere(vec3 p, vec3 c, float ra);
float obj1(vec3 pos, vec3 c, vec3 ra);  // Composite example
```

---

### hg_sdf.glsl

**Purpose:** Mercury's comprehensive SDF library.

**Key exports:**
```glsl
// Primitives
float fSphere(vec3 p, float r);
float fBox(vec3 p, vec3 b);
float fPlane(vec3 p, vec3 n, float distanceFromOrigin);
float fCylinder(vec3 p, float r, float height);
float fCapsule(vec3 p, float r, float c);
float fTorus(vec3 p, float smallRadius, float largeRadius);
// ... many more

// Boolean operations
float fOpUnion(float a, float b);
float fOpIntersection(float a, float b);
float fOpSubtraction(float a, float b);
float fOpUnionRound(float a, float b, float r);
// ... smooth variants

// Domain operations
void pR(inout vec2 p, float a);       // 2D rotation
void pMirror(inout float p, float d); // Mirror
float pMod1(inout float p, float s);  // Repetition
// ... many more
```

---

### rotate.glsl

**Purpose:** Rotation matrix utilities.

**Key exports:**
```glsl
mat3 getRotationMatrix(vec3 axis, float angle);
```

---

### noise.glsl

**Purpose:** Noise functions.

**Key exports:**
```glsl
float noise(vec3 p);
float fbm(vec3 p);  // Fractal Brownian motion
// Implementation varies
```

---

### modifiers.glsl

**Purpose:** SDF modifiers (displacement, twist, bend).

**Key exports:**
```glsl
// Varies by implementation
float displacement(vec3 p);
vec3 twist(vec3 p, float amount);
vec3 bend(vec3 p, float amount);
```

---

### color.glsl

**Purpose:** Color manipulation utilities.

**Key exports:**
```glsl
vec3 rgb2hsv(vec3 c);
vec3 hsv2rgb(vec3 c);
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d);
// Implementation varies
```

---

### fog.glsl

**Purpose:** Atmospheric fog effects.

**Key exports:**
```glsl
vec3 applyFog(vec3 col, float dist, vec3 fogColor, float fogDensity);
// Implementation varies
```

---

### domain-repetition.glsl

**Purpose:** Space folding and repetition.

**Key exports:**
```glsl
vec3 opRep(vec3 p, vec3 c);           // Infinite repetition
vec3 opRepLim(vec3 p, vec3 c, vec3 l); // Limited repetition
// Implementation varies
```

---

### anti-aliasing.glsl

**Purpose:** Anti-aliasing utilities.

**Key exports:**
```glsl
// Implementation varies - typically supersampling helpers
```

---

## Programs

### raymarching-template.fp.glsl

**Purpose:** Fragment shader entry point.

**Key sections:**
```glsl
#version 330 core

// DoF toggle
// #define DOF_ENABLED
// #define DOF_SAMPLES 4

void main(void) {
    // Camera setup
    // Raymarching (with or without DoF)
    // Surface shading via shadeHit()
    // Post-processing via getPostProcessing()
    // Output
}
```

---

### raymarching-template.vp.glsl

**Purpose:** Vertex shader (passthrough).

**Key sections:**
```glsl
#version 330 core
// Passes position and texcoord to fragment shader
```

---

## Include Order Summary

```
globals.glsl          → Constants, uniforms, flags
    ↓
noise.glsl            → Noise functions (no deps)
modifiers.glsl        → SDF modifiers (no deps)
rotate.glsl           → Rotation matrices (no deps)
    ↓
hg_sdf.glsl           → Mercury SDF library
sdf.glsl              → Custom SDFs
    ↓
materials.glsl        → Materials (uses globals)
    ↓
fog.glsl              → Fog (no deps)
domain-repetition.glsl → Domain ops (no deps)
    ↓
lighting.glsl         → Lighting (uses materials, sdfs)
color.glsl            → Color utils (no deps)
    ↓
camera.glsl           → Camera, shading (uses lighting)
    ↓
post.glsl             → Post-process (uses color, camera)
    ↓
marching-engine.glsl  → Scene, raymarch (uses all above)
```

## Quick Function Lookup

| Need to... | Function | Module |
|------------|----------|--------|
| Create material | `createMaterial()`, `mat*()` | materials.glsl |
| Blend materials | `mixMaterial()` | materials.glsl |
| Add object to scene | `sceneResult()`, `sceneMin()` | marching-engine.glsl |
| Smooth blend objects | `sceneSmin()` | marching-engine.glsl |
| Calculate normal | `getNorm()` | lighting.glsl |
| Add point light | `getPointLight()` | lighting.glsl |
| Add spotlight | `getSpotLight()` | lighting.glsl |
| Get ambient occlusion | `getAmbientOcclusion()` | lighting.glsl |
| Calculate shadows | `getShadow()`, `getColoredShadow()` | lighting.glsl |
| Shade surface | `shadeHit()` | camera.glsl |
| Add DoF | `getDoFOffset()` | camera.glsl |
| Trace refraction | `traceRefraction()` | camera.glsl |
| Add reflection | `getFirstReflection()` | lighting.glsl |
| Post-process | `getPostProcessing()` | post.glsl |
| Rotate object | `getRotationMatrix()` | rotate.glsl |
| Repeat object | `pMod1()`, `opRep()` | hg_sdf.glsl, domain-repetition.glsl |
