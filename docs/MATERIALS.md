# Materials System

This document covers the material system, including the Material struct, preset materials, and how to create custom materials.

## Material Structure

All materials use the unified `Material` struct defined in `modules/materials.glsl`:

```glsl
struct Material {
    vec3 albedo;         // Base color (RGB 0-1)
    float metallic;      // 0 = dielectric, 1 = metal
    float roughness;     // 0 = mirror, 1 = fully diffuse
    vec3 emission;       // Self-illumination color (black = none)
    float iridescence;   // 0 = none, 1 = full thin-film effect
    float subsurface;    // 0 = none, 1 = full SSS
    vec3 subsurfaceCol;  // Color of scattered light
    float transmission;  // 0 = opaque, 1 = fully transparent
    float ior;           // Index of refraction (1.0 = air)
    float toonSteps;     // 0 = disable, >0 = number of bands
};
```

## Material Properties Reference

### Basic Properties

| Property | Range | Description |
|----------|-------|-------------|
| `albedo` | vec3(0-1) | Base surface color |
| `metallic` | 0-1 | Metal (1) vs dielectric (0). Metals tint reflections with albedo |
| `roughness` | 0-1 | Surface micro-roughness. 0 = mirror, 1 = matte |

### Advanced Properties

| Property | Range | Description |
|----------|-------|-------------|
| `emission` | vec3 | Self-illumination. Color * intensity |
| `iridescence` | 0-1 | Thin-film interference (soap bubbles, oil slicks) |
| `subsurface` | 0-1 | Subsurface scattering amount (wax, skin, jade) |
| `subsurfaceCol` | vec3 | Color light takes when scattered inside |
| `transmission` | 0-1 | Transparency for refraction |
| `ior` | 1.0+ | Index of refraction (glass ~1.5, water ~1.33, diamond ~2.4) |
| `toonSteps` | 0 or 2+ | Number of discrete lighting bands for cel shading |

## Creating Materials

### Using createMaterial()

Multiple overloads for convenience:

```glsl
// Basic dielectric
Material mat = createMaterial(vec3(0.8, 0.2, 0.2));  // Red, default roughness

// With metallic/roughness
Material mat = createMaterial(vec3(1.0, 0.8, 0.3), 1.0, 0.1);  // Gold-like

// With emission
Material mat = createMaterial(albedo, metallic, roughness, emission);

// With iridescence
Material mat = createMaterial(albedo, metallic, roughness, emission, iridescence);

// Full control (except transmission/ior/toon)
Material mat = createMaterial(albedo, metallic, roughness, emission, 
                              iridescence, subsurface, subsurfaceCol);
```

### Direct Construction

For full control including transmission:

```glsl
Material mat = Material(
    vec3(0.9, 0.95, 1.0),  // albedo
    0.0,                    // metallic
    0.1,                    // roughness
    vec3(0.0),              // emission
    0.0,                    // iridescence
    0.0,                    // subsurface
    vec3(1.0),              // subsurfaceCol
    0.95,                   // transmission
    1.5,                    // ior
    0.0                     // toonSteps
);
```

## Preset Materials

### Basic Materials

| Function | Description | Key Properties |
|----------|-------------|----------------|
| `matPlastic(color)` | Shiny plastic | roughness: 0.4 |
| `matRubber(color)` | Matte rubber | roughness: 0.9 |
| `matMetal(color)` | Polished metal | metallic: 1.0, roughness: 0.3 |
| `matRoughMetal(color)` | Brushed metal | metallic: 1.0, roughness: 0.7 |
| `matMirror()` | Perfect mirror | metallic: 1.0, roughness: 0.0 |
| `matGold()` | Polished gold | metallic: 1.0, roughness: 0.05, warm color |

### Emissive Materials

| Function | Description | Intensity |
|----------|-------------|-----------|
| `matGlow(color, intensity)` | Generic glow | user-defined |
| `matNeon(color)` | Neon light | 4x |
| `matLava(color)` | Molten material | 3x, darkened albedo |
| `matHotMetal(color)` | Heated metal | 2.5x, partially metallic |

### Iridescent Materials

| Function | Description | Iridescence |
|----------|-------------|-------------|
| `matSoapBubble()` | Soap bubble | 1.0 |
| `matOilSlick()` | Oil on water | 0.9 |
| `matBeetleShell(color)` | Beetle carapace | 0.7, metallic |
| `matPearl()` | Pearl | 0.4 |

### Subsurface Scattering Materials

| Function | Description | SSS Color |
|----------|-------------|-----------|
| `matWax(color)` | Candle wax | orange/red |
| `matSkin(color)` | Human skin | red (blood) |
| `matJade(color)` | Jade stone | green |
| `matMarble()` | Marble | warm white |

### Transparent Materials

| Function | Description | IOR |
|----------|-------------|-----|
| `matGlass()` | Amber glass | 1.52 |
| `matWater()` | Ocean water | 1.33 |
| `matCrystal()` | Amethyst gem | 2.0 |

### Stylized Materials

| Function | Description |
|----------|-------------|
| `matToon(color, steps)` | Cel-shaded material |

## Blending Materials

Use `mixMaterial()` for smooth transitions:

```glsl
Material a = matMetal(vec3(1.0, 0.8, 0.3));
Material b = matRubber(vec3(0.2, 0.5, 0.3));
Material blended = mixMaterial(a, b, 0.5);  // 50/50 blend
```

Combined with `sceneSmin()` for organic material blends:

```glsl
SceneResult sphere1 = sceneResult(fSphere(p1, r), matGold());
SceneResult sphere2 = sceneResult(fSphere(p2, r), matRubber(green));
SceneResult blended = sceneSmin(sphere1, sphere2, 0.1);  // Smooth blend
```

## Usage in Scene

Materials are assigned in `getDist()` via `sceneResult()`:

```glsl
vec4 getDist(vec3 pos) {
    // Create scene result with material
    SceneResult sphere = sceneResult(
        fSphere(pos - center, radius),
        matPlastic(vec3(1.0, 0.0, 0.0))
    );
    
    // Combine with scene
    scene = sceneMin(scene, sphere);
    
    // Set global for lighting
    gMaterial = scene.mat;
    
    return vec4(scene.mat.albedo, scene.dist);
}
```

## Feature Flags

Materials using advanced features require their flags to be enabled:

| Feature | Flag | Materials Affected |
|---------|------|-------------------|
| Iridescence | `RM_ENABLE_IRIDESCENCE` | SoapBubble, OilSlick, BeetleShell, Pearl |
| SSS | `RM_ENABLE_SSS` | Wax, Skin, Jade, Marble |
| Refraction | `RM_ENABLE_REFRACTION` | Glass, Water, Crystal |
| Toon | `RM_ENABLE_TOON` | Toon materials |
| Emissive | `RM_ENABLE_EMISSIVE` | Glow, Neon, Lava, HotMetal |

See [FEATURE-FLAGS.md](./FEATURE-FLAGS.md) for toggle details.

## Performance Considerations

**Complexity ranking (cheapest to most expensive):**

1. **Basic** (Plastic, Rubber, Metal) - Standard PBR
2. **Emissive** - Adds emission term
3. **Iridescent** - View-dependent color calculation
4. **Toon** - Stepped lighting (actually cheaper than PBR)
5. **SSS** - Thickness sampling (4+ SDF evaluations)
6. **Transparent** - Full refraction trace (64+ steps through object)

For performance-critical scenes, prefer basic materials and use advanced materials sparingly.
