# Utilities Reference

This document covers noise functions, the raymarching engine, and miscellaneous helper utilities.

**Files:** `modules/noise.glsl`, `modules/marching-engine.glsl`, `globals.glsl`

---

## Noise Functions

**File:** `modules/noise.glsl`

### hash

High-quality 3D hash function.

```glsl
vec3 hash(uvec3 x)
```

#### Purpose

Generates pseudo-random vec3 in [0, 1] from integer coordinates. Useful for procedural texturing, variation, and noise generation.

#### Mathematical Basis

Uses the Linear Congruential Generator (LCG) pattern with the multiplier 1103515245 (from glibc). Three rounds of mixing ensure good distribution.

#### Implementation

```glsl
vec3 hash(uvec3 x) {
    x = ((x >> 8U) ^ x.yzx) * 1103515245U;
    x = ((x >> 8U) ^ x.yzx) * 1103515245U;
    x = ((x >> 8U) ^ x.yzx) * 1103515245U;
    return vec3(x) * (1.0 / float(0xffffffffU));
}
```

**Complexity:** O(1)

#### Usage

```glsl
// Random color per grid cell
vec3 cellColor = hash(uvec3(floor(pos * 10.0)));

// Random offset per instance
vec3 offset = (hash(uvec3(instanceId, 0, 0)) - 0.5) * 2.0;
```

---

## Raymarching Engine

**File:** `modules/marching-engine.glsl`

### SceneResult Structure

Helper for combining SDFs with full material information.

```glsl
struct SceneResult {
    float dist;
    Material mat;
};
```

### sceneResult

Creates a SceneResult from distance and material.

```glsl
SceneResult sceneResult(float dist, Material mat)
```

#### Implementation

```glsl
SceneResult sceneResult(float dist, Material mat) {
    return SceneResult(dist, mat);
}
```

### sceneMin

Union of two scene results (keeps closer object).

```glsl
SceneResult sceneMin(SceneResult a, SceneResult b)
```

#### Implementation

```glsl
SceneResult sceneMin(SceneResult a, SceneResult b) {
    return (a.dist < b.dist) ? a : b;
}
```

### sceneSmin

Smooth union with material blending.

```glsl
SceneResult sceneSmin(SceneResult a, SceneResult b, float k)
```

#### Implementation

```glsl
SceneResult sceneSmin(SceneResult a, SceneResult b, float k) {
    float h = clamp(0.5 + 0.5 * (b.dist - a.dist) / k, 0.0, 1.0);
    float dist = mix(b.dist, a.dist, h) - k * h * (1.0 - h);
    Material mat = mixMaterial(b.mat, a.mat, h);
    return SceneResult(dist, mat);
}
```

---

### getDist

Scene SDF dispatcher. Routes to the active scene based on compile-time configuration.

```glsl
vec4 getDist(vec3 pos)
```

#### Implementation

```glsl
vec4 getDist(vec3 pos) {
#if RM_ACTIVE_SCENE == SCENE_SHOWCASE
    return showcaseScene(pos);
#elif RM_ACTIVE_SCENE == SCENE_CAUSTICS
    return causticScene(pos);
#elif RM_ACTIVE_SCENE == SCENE_SSS_DEMO
    return sssDemoScene(pos);
#endif
}
```

---

### map

Core raymarching loop.

```glsl
vec4 map(vec3 ro, vec3 rd)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `ro` | vec3 | Ray origin (camera position) |
| `rd` | vec3 | Ray direction (normalized) |

#### Returns
`vec4(albedo.rgb, totalDistance)` - Material color and distance traveled.

#### Algorithm (Sphere Tracing)

1. Start at `nearClip` distance from camera
2. Sample SDF at current position
3. Step forward by the SDF distance
4. Stop when:
   - Distance < `MIN_DIST` (hit surface)
   - Total distance > `farClip` (missed scene)
   - Exceeded `MAX_STEPS`

#### Implementation

```glsl
vec4 map(vec3 ro, vec3 rd) {
    float currDist = nearClip;
    vec4 scene;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 pos = ro + rd * currDist;
        scene = getDist(pos);
        float dist = scene.w;
        currDist += dist;
        
        if (abs(dist) < MIN_DIST || currDist > farClip) {
            break;
        }
    }
    
    return vec4(scene.rgb, currDist);
}
```

**Complexity:** O(MAX_STEPS) worst case, typically O(log(distance)) for smooth SDFs.

---

## Global Configuration

**File:** `globals.glsl`

### Scene Selection

```glsl
#define SCENE_SHOWCASE 0
#define SCENE_CAUSTICS 1
#define SCENE_SSS_DEMO 2

#define RM_ACTIVE_SCENE SCENE_SSS_DEMO  // Currently active scene
```

### Raymarching Parameters

| Define | Default | Description |
|--------|---------|-------------|
| `MAX_STEPS` | 500 | Maximum ray iterations |
| `MIN_DIST` | 0.0001 | Surface hit threshold |

#### Tuning Guidelines

**MAX_STEPS:**
- 100-200: Fast, may miss thin features
- 300-500: Good balance
- 1000+: High quality, slower

**MIN_DIST:**
- 0.0001: High precision, may cause noise
- 0.001: Good balance
- 0.01: Fast, visible stepping artifacts

---

### Feature Flags

```glsl
#define RM_ENABLE_IRIDESCENCE 1
#define RM_ENABLE_SSS 1
#define RM_ENABLE_EMISSIVE 1
#define RM_ENABLE_TOON 1
#define RM_ENABLE_REFRACTION 1
#define RM_ENABLE_REFLECTIONS 1
#define RM_ENABLE_SPOTLIGHT 1
#define RM_ENABLE_AMBIENT_OCCLUSION 1
#define RM_ENABLE_CAUSTIC_SHADOWS 1
```

Set to `0` to disable features (improves performance).

---

### Shared Uniforms

```glsl
uniform float iTime;           // Elapsed time in seconds
uniform vec2 iResolution;      // Viewport size in pixels
uniform vec3 lightPos;         // Main directional light position
uniform vec3 camPos;           // Camera position
uniform float farClip;         // Far clipping distance
uniform float nearClip;        // Near clipping distance
```

---

## Helper Patterns

### Pseudo-Random from Position

```glsl
float random(vec3 pos) {
    return fract(sin(dot(pos, vec3(12.9898, 78.233, 45.5432))) * 43758.5453);
}
```

Simple single-value random from 3D position.

### Smooth Noise

```glsl
float smoothNoise(vec3 pos) {
    vec3 i = floor(pos);
    vec3 f = fract(pos);
    f = f * f * (3.0 - 2.0 * f);  // Smoothstep
    
    float a = random(i);
    float b = random(i + vec3(1, 0, 0));
    float c = random(i + vec3(0, 1, 0));
    float d = random(i + vec3(1, 1, 0));
    float e = random(i + vec3(0, 0, 1));
    float f_ = random(i + vec3(1, 0, 1));
    float g = random(i + vec3(0, 1, 1));
    float h = random(i + vec3(1, 1, 1));
    
    return mix(
        mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
        mix(mix(e, f_, f.x), mix(g, h, f.x), f.y),
        f.z
    );
}
```

### Fractal Brownian Motion (fBm)

```glsl
float fbm(vec3 pos, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * smoothNoise(pos * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}
```

Layered noise for terrain, clouds, organic textures.

### Animation Helpers

```glsl
// Smooth loop (0 to 1 and back)
float pingPong = abs(fract(iTime * 0.5) * 2.0 - 1.0);

// Smooth oscillation
float wave = sin(iTime * 2.0) * 0.5 + 0.5;

// Stepped animation
float stepped = floor(iTime * 4.0) / 4.0;

// Eased animation
float t = fract(iTime);
float eased = t * t * (3.0 - 2.0 * t);  // Smoothstep
```

---

## Common Utilities Not in Modules

These patterns appear frequently but aren't in dedicated modules:

### UV Coordinate Normalization

```glsl
// Aspect-corrected UV centered at screen center
vec2 uv = (gl_FragCoord.xy - 0.5 * iResolution.xy) / iResolution.y;

// 0-1 range UV
vec2 uv01 = gl_FragCoord.xy / iResolution.xy;
```

### Ray Generation

```glsl
vec3 getRayDirection(vec2 uv, mat3 camMat, float fov) {
    return normalize(camMat * vec3(uv, 1.0 / tan(fov * 0.5)));
}
```

### Distance Field Operations

```glsl
// Elongate an SDF (stretch without scaling)
float elongate(vec3 p, vec3 h) {
    vec3 q = abs(p) - h;
    return SDFsomething(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// Twist around Y axis
vec3 twist(vec3 p, float k) {
    float c = cos(k * p.y);
    float s = sin(k * p.y);
    mat2 m = mat2(c, -s, s, c);
    return vec3(m * p.xz, p.y);
}

// Bend around X axis
vec3 bend(vec3 p, float k) {
    float c = cos(k * p.x);
    float s = sin(k * p.x);
    mat2 m = mat2(c, -s, s, c);
    return vec3(p.x, m * p.yz);
}
```

### Safe Division

```glsl
float safeDivide(float a, float b) {
    return a / max(abs(b), 0.0001) * sign(b);
}
```

### Remapping

```glsl
float remap(float value, float inMin, float inMax, float outMin, float outMax) {
    return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
}
```

---

## Performance Tips

### Early Ray Termination

```glsl
// Skip expensive calculations for background
if (dist > farClip * 0.99) {
    return backgroundColor;
}
```

### Bounding Volume Acceleration

```glsl
float scene(vec3 pos) {
    // Quick bounding sphere check
    float boundDist = SDFsphere(pos, objectCenter, boundRadius);
    if (boundDist > 0.1) return boundDist;
    
    // Expensive detailed SDF
    return detailedSDF(pos);
}
```

### LOD (Level of Detail)

```glsl
float scene(vec3 pos, float rayDist) {
    // Simpler shapes for distant objects
    if (rayDist > 10.0) {
        return simplifiedSDF(pos);
    }
    return detailedSDF(pos);
}
```
