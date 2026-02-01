# Materials Reference

The material system provides a comprehensive PBR (Physically-Based Rendering) workflow with support for metallic, dielectric, emissive, iridescent, subsurface scattering, and transmissive materials.

**File:** `modules/materials.glsl`

---

## Material Structure

```glsl
struct Material {
    vec3 albedo;        // Base color
    float metallic;     // 0 = dielectric, 1 = metal
    float roughness;    // 0 = mirror smooth, 1 = fully diffuse
    vec3 emission;      // Self-illumination color
    float iridescence;  // Thin-film interference effect
    float subsurface;   // Subsurface scattering amount
    vec3 subsurfaceCol; // SSS transmission color
    float transmission; // Transparency (0 = opaque, 1 = glass)
    float ior;          // Index of refraction
    float toonSteps;    // Cel-shading band count (0 = disabled)
};
```

### Property Descriptions

| Property | Range | Description |
|----------|-------|-------------|
| `albedo` | vec3(0-1) | Base diffuse color. For metals, this tints reflections. |
| `metallic` | 0-1 | Metalness. 0 = plastic/wood (white specular), 1 = metal (colored specular) |
| `roughness` | 0-1 | Surface roughness. 0 = perfect mirror, 1 = completely diffuse |
| `emission` | vec3(0+) | Self-illumination. Objects with emission glow and light nearby surfaces. |
| `iridescence` | 0-1 | Thin-film interference. Creates rainbow color shifts based on view angle. |
| `subsurface` | 0-1 | SSS intensity. Light penetrates and scatters inside the material. |
| `subsurfaceCol` | vec3(0-1) | Color of light transmitted through SSS material. |
| `transmission` | 0-1 | Transparency. 1 = fully transparent (glass/water). |
| `ior` | 1.0+ | Index of refraction. Air=1.0, Water=1.33, Glass=1.5, Diamond=2.4 |
| `toonSteps` | 0+ | Cel-shading bands. 0 = disabled, 3-5 = typical cartoon look. |

---

## Global Material State

```glsl
Material gMaterial = Material(
    vec3(0.5),  // albedo
    0.0,        // metallic
    0.5,        // roughness
    vec3(0.0),  // emission
    0.0,        // iridescence
    0.0,        // subsurface
    vec3(1.0),  // subsurfaceCol
    0.0,        // transmission
    1.0,        // ior
    0.0         // toonSteps
);
```

The global `gMaterial` is set by your scene's `getDist()` function and read by the lighting system. This pattern allows material information to flow from SDF evaluation to shading without complex return types.

### Usage Pattern

```glsl
vec4 myScene(vec3 pos) {
    float d = SDFsphere(pos, vec3(0.0), 0.5);
    
    // Set global material before returning
    gMaterial = matGold();
    
    return vec4(gMaterial.albedo, d);
}
```

---

## Material Creation Functions

### Basic Constructors

```glsl
// Simple dielectric with default roughness
Material createMaterial(vec3 albedo)

// With metallic/roughness control
Material createMaterial(vec3 albedo, float metallic, float roughness)

// With emission
Material createMaterial(vec3 albedo, float metallic, float roughness, vec3 emission)

// With iridescence
Material createMaterial(vec3 albedo, float metallic, float roughness, 
                        vec3 emission, float iridescence)

// Full control
Material createMaterial(vec3 albedo, float metallic, float roughness,
                        vec3 emission, float iridescence, 
                        float subsurface, vec3 subsurfaceCol)
```

---

## Preset Materials

### Basic Materials

#### matPlastic

Standard plastic/painted surface.

```glsl
Material matPlastic(vec3 color)
```

**Properties:**
- Metallic: 0.0 (dielectric)
- Roughness: 0.4 (slight gloss)
- White specular highlights

**Usage:**
```glsl
gMaterial = matPlastic(vec3(1.0, 0.2, 0.2));  // Red plastic
```

---

#### matMetal

Polished metal surface.

```glsl
Material matMetal(vec3 color)
```

**Properties:**
- Metallic: 1.0
- Roughness: 0.3 (moderately shiny)
- Specular tinted with albedo color

**Physical Basis:** Metals have no subsurface scattering—all light interaction happens at the surface. The color comes entirely from wavelength-dependent reflection.

---

#### matGold

Pre-configured polished gold.

```glsl
Material matGold()
```

**Properties:**
- Albedo: `vec3(1.0, 0.76, 0.33)` (gold's characteristic color)
- Metallic: 1.0
- Roughness: 0.05 (highly polished)

**Physical Basis:** Gold's distinctive warm color comes from its reflectance curve—it absorbs blue wavelengths and reflects red/yellow strongly.

---

#### matRoughMetal

Brushed or weathered metal.

```glsl
Material matRoughMetal(vec3 color)
```

**Properties:**
- Metallic: 1.0
- Roughness: 0.7 (significant diffusion)

---

#### matMirror

Perfect reflector.

```glsl
Material matMirror()
```

**Properties:**
- Metallic: 1.0
- Roughness: 0.0 (perfect smoothness)
- Albedo: `vec3(0.9)` (near-white)

---

#### matRubber

Matte rubber/silicone.

```glsl
Material matRubber(vec3 color)
```

**Properties:**
- Metallic: 0.0
- Roughness: 0.9 (very diffuse)

---

### Emissive Materials

#### matGlow

General-purpose glowing material.

```glsl
Material matGlow(vec3 color, float intensity)
```

**Properties:**
- Emission: `color * intensity`
- Roughness: 1.0 (fully diffuse base)

**Usage:**
```glsl
gMaterial = matGlow(vec3(1.0, 0.5, 0.0), 3.0);  // Orange glow
```

---

#### matNeon

Bright neon sign effect.

```glsl
Material matNeon(vec3 color)
```

**Properties:**
- Emission: `color * 4.0` (very bright)
- Roughness: 0.8

---

#### matLava

Molten material with glow.

```glsl
Material matLava(vec3 color)
```

**Properties:**
- Albedo: `color * 0.5` (darkened base)
- Emission: `color * 3.0`
- Roughness: 0.9

---

#### matHotMetal

Glowing heated metal.

```glsl
Material matHotMetal(vec3 color)
```

**Properties:**
- Metallic: 0.8 (mostly metallic)
- Roughness: 0.4
- Emission: `color * 2.5`

---

### Iridescent Materials

Iridescence simulates thin-film interference where color changes based on viewing angle.

#### matSoapBubble

Thin soap film appearance.

```glsl
Material matSoapBubble()
```

**Properties:**
- Albedo: Near-white `vec3(0.9, 0.95, 1.0)`
- Iridescence: 1.0 (full effect)
- Roughness: 0.1

---

#### matOilSlick

Oil-on-water rainbow effect.

```glsl
Material matOilSlick()
```

**Properties:**
- Albedo: Dark `vec3(0.05, 0.05, 0.1)`
- Metallic: 0.3 (slight metallic base)
- Iridescence: 0.9

---

#### matBeetleShell

Metallic beetle carapace.

```glsl
Material matBeetleShell(vec3 baseColor)
```

**Properties:**
- Metallic: 0.6
- Iridescence: 0.7
- Roughness: 0.3

---

#### matPearl

Pearl luster effect.

```glsl
Material matPearl()
```

**Properties:**
- Albedo: Warm white `vec3(0.95, 0.93, 0.88)`
- Iridescence: 0.4 (subtle)
- Roughness: 0.3

---

### Iridescence Mathematics

```glsl
vec3 getIridescentColor(float viewAngle, vec3 baseColor)
```

#### Physical Basis

Thin-film interference occurs when light reflects from both the top and bottom surfaces of a thin layer. The two reflections interfere constructively or destructively based on:

1. Film thickness
2. Viewing angle (path length through film)
3. Wavelength

#### Implementation

```glsl
vec3 getIridescentColor(float viewAngle, vec3 baseColor) {
    // Shift through hues based on angle
    float hue = fract(viewAngle * 2.0 + 0.5);
    
    // Rainbow palette (HSV-like)
    vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (hue + vec3(0.0, 0.33, 0.67)));
    
    // Stronger at glancing angles
    float strength = pow(1.0 - viewAngle, 2.0);
    
    return mix(baseColor, rainbow, strength * 0.8);
}
```

---

### Subsurface Scattering Materials

SSS simulates light penetrating translucent materials like skin, wax, jade, and marble.

#### matWax

Candle/beeswax material.

```glsl
Material matWax(vec3 color)
```

**Properties:**
- Subsurface: 1.0 (strong SSS)
- SubsurfaceCol: `vec3(1.0, 0.5, 0.2)` (warm orange transmission)
- Roughness: 0.6

---

#### matSkin

Realistic flesh/skin.

```glsl
Material matSkin(vec3 color)
```

**Properties:**
- Subsurface: 0.9
- SubsurfaceCol: `vec3(1.0, 0.2, 0.1)` (red blood color)
- Roughness: 0.5

**Physical Basis:** Skin's characteristic look comes from light penetrating the outer layer and scattering off blood vessels beneath, giving it a red undertone especially at thin areas (ears, fingers).

---

#### matJade

Green jade stone.

```glsl
Material matJade(vec3 color)
```

**Properties:**
- Subsurface: 1.0
- SubsurfaceCol: `vec3(0.3, 1.0, 0.4)` (bright green glow)
- Roughness: 0.3 (polished stone)

---

#### matMarble

White marble stone.

```glsl
Material matMarble()
```

**Properties:**
- Albedo: `vec3(0.95, 0.93, 0.9)`
- Subsurface: 0.7
- SubsurfaceCol: `vec3(1.0, 0.9, 0.7)` (warm cream)
- Roughness: 0.2

---

#### matGummyBear

Translucent candy gel.

```glsl
Material matGummyBear(vec3 color)
```

**Properties:**
- Subsurface: 2.4 (boosted for candy look)
- Roughness: 0.10 (glossy gel surface)
- SubsurfaceCol: Derived from color with red/orange bias

---

### Transmissive Materials

For transparent/refractive objects like glass and water.

#### matGlass

Amber-tinted glass.

```glsl
Material matGlass()
```

**Properties:**
- Albedo: `vec3(0.95, 0.75, 0.5)` (warm amber)
- Transmission: 0.92
- IOR: 1.52 (typical crown glass)
- Roughness: 0.12

---

#### matWater

Clear water/liquid.

```glsl
Material matWater()
```

**Properties:**
- Albedo: `vec3(0.3, 0.85, 0.95)` (aqua tint)
- Transmission: 0.98 (nearly fully transparent)
- IOR: 1.33 (water)
- Roughness: 0.02

---

#### matCrystal

Amethyst-like gem.

```glsl
Material matCrystal()
```

**Properties:**
- Albedo: `vec3(0.7, 0.3, 0.9)` (purple)
- Transmission: 0.96
- IOR: 2.0 (high refraction)
- Iridescence: 0.15 (slight internal rainbows)

---

### Toon Materials

For cel-shaded/cartoon rendering.

#### matToon

```glsl
Material matToon(vec3 color, float steps)
```

**Parameters:**
- `steps`: Number of shading bands (3-5 typical)

**Usage:**
```glsl
gMaterial = matToon(vec3(1.0, 0.5, 0.0), 4.0);  // 4-band orange
```

---

## Material Blending

### mixMaterial

Interpolates between two materials.

```glsl
Material mixMaterial(Material a, Material b, float t)
```

**Parameters:**
- `a`, `b`: Materials to blend
- `t`: Blend factor (0 = a, 1 = b)

**Usage:**
```glsl
// Transition from plastic to metal based on height
float t = smoothstep(0.0, 1.0, pos.y);
gMaterial = mixMaterial(matPlastic(vec3(0.8)), matGold(), t);
```

This linearly interpolates all material properties, useful for:
- Smooth material transitions at boundaries
- Animated material changes
- Procedural material variation

---

## Scene Result Pattern

For cleaner scene construction, use the `SceneResult` helper:

```glsl
struct SceneResult {
    float dist;
    Material mat;
};

SceneResult sceneResult(float dist, Material mat);
SceneResult sceneMin(SceneResult a, SceneResult b);
SceneResult sceneSmin(SceneResult a, SceneResult b, float k);
```

**Usage:**
```glsl
SceneResult scene(vec3 pos) {
    SceneResult sphere = sceneResult(
        SDFsphere(pos, vec3(0.0), 0.5),
        matGold()
    );
    
    SceneResult ground = sceneResult(
        pos.y + 0.5,
        matPlastic(vec3(0.3))
    );
    
    return sceneMin(sphere, ground);
}
```

---

## Emissive Light Sources

### Configuration

Scenes can define emissive objects that illuminate nearby surfaces:

```glsl
vec4 getEmissiveSource(int index)      // Returns: position.xyz, radius.w
vec4 getEmissiveProperties(int index)  // Returns: color.xyz, intensity.w
```

### Lighting Calculation

Emissive objects contribute soft illumination:

```glsl
for (int i = 0; i < NUM_EMISSIVES; i++) {
    vec4 source = getEmissiveSource(i);
    vec4 props = getEmissiveProperties(i);
    
    vec3 emissivePos = source.xyz;
    float emissiveRadius = source.w;
    vec3 emissiveCol = props.xyz * props.w;
    
    // Wrap lighting for soft diffuse
    float emissiveDiffuse = max(dot(normals, emissiveDir) * 0.5 + 0.5, 0.0);
    
    // Distance falloff from sphere surface
    float effectiveDist = max(distToEmissive - emissiveRadius, 0.001);
    float emissiveAtt = 1.0 / (1.0 + effectiveDist * effectiveDist * 5.0);
    
    col += emissiveDiffuse * emissiveAtt * emissiveCol * mate;
}
```
