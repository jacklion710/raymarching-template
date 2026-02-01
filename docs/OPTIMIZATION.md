# Optimization Overview

This document summarizes the performance systems available in the raymarching template and how to tune them.

## Quick Wins (Order of Impact)

1. **Feature flags**: disable expensive effects you don't need.
2. **LOD + step scaling**: keep quality near camera, reduce cost far away.
3. **Sky early-out**: skip raymarching for sky-dominant primary rays.
4. **Shadow/AO LOD**: reduce sampling for distant hits.
5. **Scene-level culling** (optional): early-out outside scene bounds (be careful not to render the bound).

## Feature Flags

Toggle in `globals.glsl`:

```glsl
#define RM_ENABLE_LOD 1
#define RM_ENABLE_STEP_SCALE 1
#define RM_ENABLE_SKY_EARLY_OUT 1
#define RM_ENABLE_CAUSTIC_SHADOWS 0  // expensive
#define RM_ENABLE_SSS 0              // expensive
#define RM_ENABLE_REFRACTION 0       // expensive
```

## LOD + Step Scaling

LOD applies distance-based quality scaling:

```glsl
#define RM_LOD_MID_RATIO 0.35
#define RM_LOD_FAR_RATIO 0.65
#define RM_LOD_MIN_DIST_SCALE_MID 2.5
#define RM_LOD_MIN_DIST_SCALE_FAR 5.0
#define RM_LOD_MAX_STEPS_SCALE_MID 0.6
#define RM_LOD_MAX_STEPS_SCALE_FAR 0.35
#define RM_STEP_SCALE_MID 1.2
#define RM_STEP_SCALE_FAR 1.5
```

Guidelines:
- Increase ratios to preserve detail at distance.
- Reduce step scales if thin geometry is missed.

## Sky Early-Out

Skips marching for rays that are very likely to hit only sky:

```glsl
#define RM_SKY_EARLY_OUT_Y 0.6
#define RM_SKY_EARLY_OUT_CAM_Y 0.05
```

If you have geometry above the camera, raise `RM_SKY_EARLY_OUT_Y` or disable.

## Shadow + AO LOD

Shadow ray distance and step size are reduced for far hits. AO sample count is reduced based on `gLodFactor`.

If you see popping:
- Lower `RM_LOD_FAR_RATIO`.
- Increase shadow max distance in `modules/lighting.glsl`.

## Material Simplification

Far hits can be simplified to diffuse-only shading. This happens in `camera.glsl` and is controlled by LOD.

If you want to preserve specular at distance, increase the LOD threshold or keep a small metallic/roughness floor.

## Scene-Level Culling

You can add a conservative bounding check inside a scene:

```glsl
float boundDist = fSphere(pos - center, radius);
if (boundDist > 0.0) {
    return vec4(0.0, 0.0, 0.0, farClip);
}
```

Important: return `farClip` (not `boundDist`) to avoid rendering the bound as geometry.
