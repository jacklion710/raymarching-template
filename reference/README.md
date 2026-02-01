# Raymarching Template Reference Guide

This reference guide provides detailed documentation for all functions, structures, and mathematical concepts used in the raymarching template. Each section explains the implementation rationale, the underlying mathematics, and practical usage examples.

## Table of Contents

1. [SDF Primitives](./SDF-PRIMITIVES.md) - Signed Distance Functions for basic shapes
2. [Lighting](./LIGHTING.md) - Light calculations, shadows, and shading models
3. [Materials](./MATERIALS.md) - Material system, presets, and properties
4. [Camera & Rendering](./CAMERA.md) - Camera setup, depth of field, and ray generation
5. [Modifiers](./MODIFIERS.md) - SDF combination operators (min, max, smooth blend)
6. [Domain Operations](./DOMAIN-OPS.md) - Space repetition, mirroring, and transformation
7. [Color & Post-Processing](./COLOR-POST.md) - Tone mapping, color grading, and effects
8. [HG_SDF Library](./HG-SDF.md) - Mercury's comprehensive SDF library reference
9. [Utilities](./UTILITIES.md) - Noise, fog, rotation, and helper functions

## Quick Start

### Understanding SDFs

A Signed Distance Function (SDF) returns the shortest distance from a point `p` to the surface of an object:
- **Positive values**: Point is outside the object
- **Negative values**: Point is inside the object
- **Zero**: Point is exactly on the surface

### Raymarching Algorithm

The core raymarching loop works by:
1. Starting at the camera position (ray origin `ro`)
2. Marching along the ray direction `rd`
3. At each step, querying the SDF to get distance to nearest surface
4. Stepping forward by that distance (sphere tracing)
5. Stopping when distance is below threshold or max steps reached

```glsl
vec4 map(vec3 ro, vec3 rd) {
    float currDist = nearClip;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 pos = ro + rd * currDist;
        vec4 scene = getDist(pos);
        float dist = scene.w;
        currDist += dist;
        if (abs(dist) < MIN_DIST || currDist > farClip) break;
    }
    return vec4(scene.rgb, currDist);
}
```

### Global Configuration

Key settings in `globals.glsl`:

| Setting | Default | Description |
|---------|---------|-------------|
| `MAX_STEPS` | 500 | Maximum raymarching iterations |
| `MIN_DIST` | 0.0001 | Surface hit threshold |
| `RM_ACTIVE_SCENE` | SCENE_SSS_DEMO | Currently active scene |

### Feature Flags

Enable/disable rendering features via preprocessor defines:

```glsl
#define RM_ENABLE_IRIDESCENCE 1      // Thin-film color shifting
#define RM_ENABLE_SSS 1               // Subsurface scattering
#define RM_ENABLE_EMISSIVE 1          // Glowing objects
#define RM_ENABLE_TOON 1              // Cel-shaded rendering
#define RM_ENABLE_REFRACTION 1        // Transparent object refraction
#define RM_ENABLE_REFLECTIONS 1       // Mirror reflections
#define RM_ENABLE_CAUSTIC_SHADOWS 1   // Colored shadows from glass
#define RM_ENABLE_AMBIENT_OCCLUSION 1 // Contact shadows
```

## Mathematical Notation

Throughout this reference:
- `p` - Position being sampled (world-space)
- `ro` - Ray origin (camera position)
- `rd` - Ray direction (normalized)
- `N` or `normals` - Surface normal
- `L` - Light direction
- `V` - View direction (typically `-rd`)
- `H` - Half vector between V and L
- `dot(a, b)` - Dot product (a · b)
- `normalize(v)` - Unit vector (v / |v|)
