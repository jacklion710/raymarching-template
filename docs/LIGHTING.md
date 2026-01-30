# Lighting System

This document covers the lighting pipeline, light types, shadow system, and material-specific lighting behaviors.

## Lighting Pipeline Overview

```
Surface Hit
    │
    ▼
┌─────────────────────────────────────────┐
│           shadeHit() [camera.glsl]      │
│  - Saves material properties            │
│  - Applies iridescence to albedo        │
│  - Calculates Fresnel                   │
└─────────────────────────────────────────┘
    │
    ├─────────────────────────────────────┐
    ▼                                     ▼
┌───────────────┐                 ┌───────────────┐
│   getLight()  │                 │  Reflections  │
│[lighting.glsl]│                 │    (if enabled)│
└───────────────┘                 └───────────────┘
    │                                     │
    ├── Main directional light            │
    ├── SSS contribution                  │
    ├── Emissive area lights              │
    ├── Spotlights                        │
    └── Point lights                      │
    │                                     │
    ▼                                     ▼
┌─────────────────────────────────────────┐
│            Refraction (if transparent)  │
│         traceRefraction() [camera.glsl] │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│              Final Composite            │
│  lighting + reflections + refraction    │
│  + emission                             │
└─────────────────────────────────────────┘
```

## Light Types

### Main Directional Light

The primary light source, controlled by `lightPos` uniform.

```glsl
// In getLight()
vec3 lightDir = normalize(hitPos - lightPos);
```

**Properties:**
- Position-based direction (not true directional)
- Configurable via Max/MSP `lightPos` parameter
- Affects diffuse, specular, shadows, SSS

### Spotlights

Cone-shaped lights with falloff:

```glsl
vec3 getSpotLight(
    vec3 hitPos,      // Surface position
    vec3 spotPos,     // Light position
    vec3 spotDir,     // Light direction
    vec3 normals,     // Surface normal
    vec3 rd,          // View direction
    vec3 spotCol,     // Light color * intensity
    float innerAngle, // Full intensity cone (radians)
    float outerAngle  // Falloff edge (radians)
);
```

**Current spotlights:**
1. SSS backlight - Behind SSS row, pointing toward camera
2. Transparent row light - Above transparent materials

### Point Lights

Omnidirectional lights with distance falloff:

```glsl
vec3 getPointLight(
    vec3 hitPos,    // Surface position
    vec3 lightPos,  // Light position
    vec3 normals,   // Surface normal
    vec3 rd,        // View direction
    vec3 refRd,     // Reflection direction
    vec3 lightCol,  // Light color * intensity
    vec3 mate       // Surface albedo
);
```

**Current point lights:**
1. Glass caustic light - Behind transparent row
2. SSS bleeding light - Behind SSS row
3. Iridescent light - Side light for rainbow shadows

### Emissive Area Lights

Self-illuminating objects that also light nearby surfaces:

```glsl
// Centralized definitions in materials.glsl
vec4 getEmissiveSource(int index);     // Position + radius
vec4 getEmissiveProperties(int index); // Color + intensity
```

**Current emissives:**
- Interior lights for SSS spheres (wax, skin, jade, marble)
- Standalone green glow sphere
- Spotlight position marker

## Shadow System

### Simple Shadows

Basic shadow calculation:

```glsl
float getSimpleShadow(vec3 hitPos, vec3 rd, float k);
```

- Returns 0.0 (full shadow) to 1.0 (no shadow)
- `k` controls penumbra softness (higher = softer)
- Emissive objects don't block light
- Transmissive objects cast partial shadows

### Colored Caustic Shadows

Advanced material-aware shadows (when `RM_ENABLE_CAUSTIC_SHADOWS` is enabled):

```glsl
vec3 getColoredShadow(vec3 hitPos, vec3 rd, float k);
```

Returns RGB shadow color for:

**Transparent materials:**
- Beer-Lambert absorption coloring
- Light focusing (caustic brightening)
- Chromatic aberration (color separation)

**SSS materials:**
- Depth-based color bleeding
- Subsurface color tinting
- Soft shadow edges

**Iridescent materials:**
- Position-dependent rainbow tinting

### Shadow Softness

Roughness affects shadow penumbra:

```glsl
float shadowSoftness = mix(16.0, 4.0, roughness);
// Smooth surfaces: sharp shadows (k=16)
// Rough surfaces: soft shadows (k=4)
```

## Material-Specific Lighting

### Standard PBR (Plastic, Metal, Rubber)

```
diffuse = albedo * NdotL * (1 - metallic * 0.9)
specular = specColor * pow(NdotH, specPower)
```

- Metals reduce diffuse, tint specular with albedo
- Roughness controls specular power

### Iridescent Materials

View-dependent color shifting:

```glsl
if (iridescence > 0.0) {
    vec3 iriColor = getIridescentColor(NdotV, albedo);
    albedo = mix(albedo, iriColor, iridescence);
}
```

- Stronger effect at glancing angles
- Enhanced Fresnel reflection
- Specular tinted with shifted color

### Subsurface Scattering

Light penetration simulation:

```glsl
// Thickness estimation
for (int i = 1; i <= 4; i++) {
    float d = getDist(hitPos - normal * dist).w;
    thickness += max(0.0, -d);
}

// Absorption (Beer-Lambert)
vec3 absorption = exp(-absorptionCoeff * thickness * 4.0);

// Surface reduction + SSS contribution
col *= surfaceReduction * absorption;
col += subsurfaceColor * scatter;
```

**Components:**
- Thickness sampling (4 SDF evaluations)
- Back-lighting (light through thin areas)
- Wrap lighting (soft edge bleeding)
- Rim scattering (view-dependent edges)

### Transparent/Refractive Materials

Full refraction trace:

```glsl
vec3 traceRefraction(hitPos, rd, normal, ior, tint, bgCol) {
    // 1. Refract at entry
    vec3 T = refract(rd, normal, 1.0/ior);
    
    // 2. March through object interior
    marchThroughObject(entryPos, T, ...);
    
    // 3. Refract at exit
    vec3 exitDir = refract(T, -exitNormal, ior);
    
    // 4. Trace what's behind
    vec4 behindScene = map(exitRo, exitDir);
    
    // 5. Apply absorption
    return behindColor * absorption;
}
```

**Fresnel blending:**
```glsl
col = refrColor * fresnelTrans + reflectionCol * fresnelRefl;
```

### Toon/Cel Shading

Stepped lighting:

```glsl
if (toonSteps > 0.0) {
    float toonDiffuse = floor(NdotL * steps) / steps;
    float toonSpec = step(0.75, spec);
}
```

- Hard shadow edges (high softness value)
- No ambient occlusion
- Discrete lighting bands

### Emissive Materials

Self-illumination:

```glsl
// Reduced external lighting
lightingFactor *= (1.0 - emissionStrength);

// Add emission at end
col += emission;
```

- Don't receive shadows
- Don't contribute to AO
- Don't block light in shadow rays

## Ambient Occlusion

Contact shadow approximation:

```glsl
float getAmbientOcclusion(vec3 hitPos, vec3 normal) {
    for (int i = 0; i < 5; i++) {
        float h = 0.01 + 0.04 * float(i) / 4.0;
        float d = getDist(hitPos + normal * h).w;
        occ += (h - d) * sca;
        sca *= 0.5;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}
```

- 5 samples along normal
- Emissive and transmissive objects excluded
- Disabled for toon materials

## Adding New Lights

### Adding a Point Light

In `getLight()` under `#if USE_POINT_LIGHT`:

```glsl
{
    vec3 myLightPos = vec3(x, y, z);
    vec3 myLightCol = vec3(r, g, b) * intensity;
    col += getPointLight(hitPos, myLightPos, normals, rd, refRd, myLightCol, mate);
}
```

### Adding a Spotlight

```glsl
{
    vec3 spotPos = vec3(x, y, z);
    vec3 spotTarget = vec3(tx, ty, tz);
    vec3 spotDir = normalize(spotTarget - spotPos);
    vec3 spotCol = vec3(r, g, b) * intensity;
    float innerAngle = 0.4;  // ~23 degrees
    float outerAngle = 0.8;  // ~46 degrees
    
    col += getSpotLight(hitPos, spotPos, spotDir, normals, rd, spotCol, innerAngle, outerAngle);
}
```

## Performance Tips

1. **Reduce light count** - Each light adds shadow rays
2. **Disable caustic shadows** - `RM_ENABLE_CAUSTIC_SHADOWS 0`
3. **Reduce AO samples** - Edit loop count in `getAmbientOcclusion()`
4. **Skip SSS for distant objects** - Add distance check
5. **Lower shadow ray distance** - Change `12.0` limit in shadow functions
