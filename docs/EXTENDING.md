# Extending the Template

This guide covers common extension tasks with step-by-step instructions.

## Table of Contents

1. [Adding a New Object](#adding-a-new-object)
2. [Creating a Custom Material](#creating-a-custom-material)
3. [Adding a New Material Preset](#adding-a-new-material-preset)
4. [Adding a New Light](#adding-a-new-light)
5. [Creating a New Feature Flag](#creating-a-new-feature-flag)
6. [Adding Post-Processing Effects](#adding-post-processing-effects)
7. [Common Pitfalls](#common-pitfalls)

---

## Adding a New Object

Objects are added in `modules/marching-engine.glsl` within the `getDist()` function.

### Basic Object

```glsl
// In getDist(), before "Set global material for lighting"

// My new sphere
vec3 myPos = pos - vec3(0.0, 0.3, 0.5);  // Position offset
SceneResult mySphere = sceneResult(
    fSphere(myPos, 0.15),                 // SDF primitive + size
    matPlastic(vec3(1.0, 0.5, 0.2))       // Material
);
scene = sceneMin(scene, mySphere);        // Add to scene
```

### Animated Object

```glsl
// Bouncing sphere
float bounce = sin(iTime * 2.0) * 0.1;
vec3 animPos = pos - vec3(0.0, 0.2 + bounce, 0.0);
SceneResult animSphere = sceneResult(
    fSphere(animPos, 0.1),
    matMetal(vec3(0.8, 0.8, 0.9))
);
scene = sceneMin(scene, animSphere);
```

### Transformed Object

```glsl
// Rotating cube
vec3 cubePos = pos - vec3(0.5, 0.2, 0.0);
mat3 rot = getRotationMatrix(vec3(0.0, 1.0, 0.0), iTime);
cubePos = rot * cubePos;
SceneResult cube = sceneResult(
    fBox(cubePos, vec3(0.1)),
    matGold()
);
scene = sceneMin(scene, cube);
```

### Conditionally Rendered Object

```glsl
#if RM_ENABLE_SSS
    // Only render when SSS is enabled
    SceneResult sssSphere = sceneResult(
        fSphere(pos - vec3(0.0, 0.3, 0.0), 0.1),
        matWax(vec3(0.9, 0.85, 0.7))
    );
    scene = sceneMin(scene, sssSphere);
#endif
```

---

## Creating a Custom Material

### Inline Material

For one-off materials, construct directly:

```glsl
Material customMat = Material(
    vec3(0.8, 0.2, 0.1),  // albedo - red
    0.0,                   // metallic - dielectric
    0.3,                   // roughness - somewhat shiny
    vec3(0.0),             // emission - none
    0.0,                   // iridescence - none
    0.0,                   // subsurface - none
    vec3(1.0),             // subsurfaceCol - unused
    0.0,                   // transmission - opaque
    1.0,                   // ior - unused when opaque
    0.0                    // toonSteps - disabled
);

SceneResult obj = sceneResult(fSphere(p, r), customMat);
```

### Material with SSS

```glsl
Material mySSS = Material(
    vec3(0.9, 0.85, 0.7),  // albedo - cream
    0.0,                    // metallic
    0.5,                    // roughness
    vec3(0.0),              // emission
    0.0,                    // iridescence
    0.8,                    // subsurface - strong SSS
    vec3(1.0, 0.6, 0.3),    // subsurfaceCol - warm orange
    0.0, 1.0, 0.0           // transmission, ior, toon
);
```

### Transparent Material

```glsl
Material myGlass = Material(
    vec3(0.95, 0.98, 1.0),  // albedo - slight blue tint
    0.0,                     // metallic
    0.05,                    // roughness - very smooth
    vec3(0.0),               // emission
    0.0,                     // iridescence
    0.0,                     // subsurface
    vec3(1.0),               // subsurfaceCol
    0.9,                     // transmission - very transparent
    1.45,                    // ior - crown glass
    0.0                      // toonSteps
);
```

---

## Adding a New Material Preset

Add to `modules/materials.glsl`:

```glsl
// O(1): My custom velvet material.
// color: base velvet color
Material matVelvet(vec3 color) {
    return Material(
        color,           // albedo
        0.0,             // metallic
        0.95,            // roughness - very matte
        vec3(0.0),       // emission
        0.0,             // iridescence
        0.3,             // subsurface - slight fuzz effect
        color * 0.5,     // subsurfaceCol - darker version
        0.0,             // transmission
        1.0,             // ior
        0.0              // toonSteps
    );
}
```

**Usage:**
```glsl
SceneResult velvetSphere = sceneResult(
    fSphere(pos - center, 0.1),
    matVelvet(vec3(0.5, 0.0, 0.2))  // Deep red velvet
);
```

---

## Adding a New Light

### Point Light

In `modules/lighting.glsl`, within `getLight()` under `#if USE_POINT_LIGHT`:

```glsl
{   // My custom point light
    vec3 myLightPos = vec3(0.3, 0.5, -0.2);
    vec3 myLightCol = vec3(1.0, 0.9, 0.7) * 0.5;  // Warm, medium intensity
    col += getPointLight(hitPos, myLightPos, normals, rd, refRd, myLightCol, mate);
}
```

### Spotlight

```glsl
{   // My custom spotlight
    vec3 spotPos = vec3(0.0, 1.0, 0.0);          // Above scene
    vec3 spotTarget = vec3(0.0, 0.0, 0.0);       // Pointing at origin
    vec3 spotDir = normalize(spotTarget - spotPos);
    vec3 spotCol = vec3(1.0, 1.0, 1.0) * 0.8;    // Bright white
    float innerAngle = 0.3;                       // ~17 degree inner cone
    float outerAngle = 0.6;                       // ~34 degree outer cone
    
    col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, innerAngle, outerAngle);
}
```

### Animated Light

```glsl
{   // Orbiting light
    float angle = iTime * 0.5;
    vec3 orbitPos = vec3(cos(angle) * 0.5, 0.3, sin(angle) * 0.5);
    vec3 orbitCol = vec3(0.2, 0.5, 1.0) * 0.4;  // Blue
    col += getPointLight(hitPos, orbitPos, normals, rd, refRd, orbitCol, mate);
}
```

---

## Creating a New Feature Flag

### Step 1: Define the Flag

In `globals.glsl`:

```glsl
#ifndef RM_ENABLE_MY_FEATURE
#define RM_ENABLE_MY_FEATURE 1
#endif
```

### Step 2: Guard the Feature Code

In relevant module files:

```glsl
#if RM_ENABLE_MY_FEATURE
    // Feature-specific code here
    vec3 myEffect = calculateMyEffect(hitPos, normal);
    col += myEffect;
#endif
```

### Step 3: Guard Related Objects

In `marching-engine.glsl`:

```glsl
#if RM_ENABLE_MY_FEATURE
    SceneResult myFeatureObj = sceneResult(
        fSphere(pos - vec3(0.0, 0.5, 0.0), 0.1),
        myFeatureMaterial()
    );
    scene = sceneMin(scene, myFeatureObj);
#endif
```

### Step 4: Document the Flag

Add to `docs/FEATURE-FLAGS.md`.

---

## Adding Post-Processing Effects

Add to `modules/post.glsl` within `getPostProcessing()`:

### Vignette

```glsl
// Vignette
float vignette = 1.0 - length(uv - 0.5) * 0.8;
col *= vignette;
```

### Color Grading

```glsl
// Warm color grade
col = pow(col, vec3(0.95, 1.0, 1.05));  // Slightly warm
col = mix(col, col * vec3(1.1, 1.0, 0.9), 0.2);  // More warmth
```

### Film Grain

```glsl
// Film grain
float grain = fract(sin(dot(uv, vec2(12.9898, 78.233)) + iTime) * 43758.5453);
col += (grain - 0.5) * 0.03;
```

### Chromatic Aberration

```glsl
// Simple chromatic aberration
vec2 caOffset = (uv - 0.5) * 0.002;
// Would need to re-render or sample texture - simplified version:
col.r *= 1.0 + length(uv - 0.5) * 0.05;
col.b *= 1.0 - length(uv - 0.5) * 0.05;
```

---

## Common Pitfalls

### 1. Include Order Errors

**Problem:** "Undeclared identifier" errors

**Cause:** Using a function before its file is included

**Solution:** Check `raymarching-template.jxs` include order. Dependencies must come first.

### 2. gMaterial Not Set

**Problem:** Materials not affecting lighting correctly

**Cause:** Forgetting to set `gMaterial = scene.mat;` in `getDist()`

**Solution:** Always set gMaterial before returning from getDist():
```glsl
gMaterial = scene.mat;
return vec4(scene.mat.albedo, scene.dist);
```

### 3. Infinite Loops in Refraction

**Problem:** Shader hangs or crashes

**Cause:** Refraction ray never exits object

**Solution:** Add maximum distance/iteration limits:
```glsl
if (thickness > 2.0) break;
```

### 4. Feature Flag Not Working

**Problem:** Code runs even when flag is 0

**Cause:** Using `#ifdef` instead of `#if`

**Solution:** Use `#if FLAG_NAME` not `#ifdef FLAG_NAME`:
```glsl
// Wrong - always true if defined (even as 0)
#ifdef RM_ENABLE_SSS

// Correct - checks actual value
#if RM_ENABLE_SSS
```

### 5. Material Properties Lost in Recursion

**Problem:** Reflected/refracted surfaces have wrong materials

**Cause:** `gMaterial` is global and gets overwritten

**Solution:** Save material properties before recursive calls:
```glsl
// Save before any getDist/map calls
float savedMetallic = gMaterial.metallic;
vec3 savedEmission = gMaterial.emission;

// ... recursive calls ...

// Use saved values, not gMaterial
```

### 6. Object Not Visible

**Problem:** Object doesn't appear in scene

**Causes:**
- Object behind camera
- Object inside another object
- Object too small/large
- Missing `sceneMin()` call

**Debug:** Add object at known position `vec3(0, 0.5, 0)` with bright color

### 7. Shadow Artifacts

**Problem:** Surface acne, banding, or incorrect shadows

**Causes:**
- Shadow ray starting inside surface
- MIN_DIST too large/small

**Solution:** Offset shadow ray origin:
```glsl
vec3 shadowRo = hitPos + normal * MIN_DIST * 2.0;
```

### 8. Performance Issues

**Symptoms:** Low framerate, stuttering

**Common causes:**
- Too many SDF operations
- Deep recursion (reflections of reflections)
- Caustic shadows enabled
- High MAX_STEPS

**Solutions:**
- Simplify scene geometry
- Limit reflection bounces
- Disable `RM_ENABLE_CAUSTIC_SHADOWS`
- Reduce `MAX_STEPS` to 200-300

---

## Complexity Comparison

When adding features, consider the effort required:

| Task | Complexity | Files Modified |
|------|------------|----------------|
| Add basic object | Low | marching-engine.glsl |
| Add animated object | Low | marching-engine.glsl |
| Use existing material preset | Low | marching-engine.glsl |
| Create inline material | Low | marching-engine.glsl |
| Add material preset | Medium | materials.glsl |
| Add point/spot light | Medium | lighting.glsl |
| Add post-processing | Medium | post.glsl |
| Create feature flag | Medium | globals.glsl + affected files |
| Add new material property | High | materials.glsl, lighting.glsl, camera.glsl |
| Add new lighting model | High | lighting.glsl, camera.glsl |

The template is designed so common tasks (adding objects, using materials) are easy, while advanced modifications are possible but require understanding the full pipeline.
