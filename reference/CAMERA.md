# Camera & Rendering Reference

This module handles camera setup, ray generation, depth of field, refraction, and final shading calculations.

**File:** `modules/camera.glsl`

---

## Depth of Field Configuration

### DoFConfig Structure

```glsl
struct DoFConfig {
    float aperture;        // Blur amount (larger = more blur)
    float blades;          // Aperture blade count (shapes bokeh)
    float bladeRotation;   // Bokeh shape rotation (radians)
    float temporalSpeed;   // Temporal jitter speed
    float temporalAmount;  // Temporal rotation amount (0-1)
};
```

### Default Configuration

```glsl
DoFConfig getDefaultDoFConfig() {
    return DoFConfig(
        0.12,   // aperture
        6.0,    // blades (hexagon)
        0.0,    // bladeRotation
        60.0,   // temporalSpeed
        0.12    // temporalAmount
    );
}
```

---

## Depth of Field Functions

### polygonRadius

Shapes circular bokeh into polygon patterns.

```glsl
float polygonRadius(float angle, float blades, float rotation)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `angle` | float | Sample angle in radians |
| `blades` | float | Number of aperture blades |
| `rotation` | float | Rotation offset in radians |

#### Mathematical Basis

A regular polygon can be described by the distance from center to edge at any angle. The formula uses the inscribed circle relationship:

```
r(θ) = cos(π/n) / cos((θ mod 2π/n) - π/n)
```

Where `n` is the number of sides.

#### Implementation

```glsl
float polygonRadius(float angle, float blades, float rotation) {
    float segment = 6.28318530718 / blades;
    float a = mod(angle + rotation, segment) - segment * 0.5;
    return cos(segment * 0.5) / cos(a);
}
```

**Blade Count Effects:**
| Blades | Shape |
|--------|-------|
| 5 | Pentagon |
| 6 | Hexagon (common camera) |
| 7 | Heptagon |
| 8 | Octagon |
| ∞ | Circle |

---

### getDoFOffset

Calculates ray origin offset for depth of field sampling.

```glsl
vec3 getDoFOffset(int sampleIndex, int sampleCount, mat3 camMat, 
                  DoFConfig config, float time)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `sampleIndex` | int | Current sample (0 to sampleCount-1) |
| `sampleCount` | int | Total DoF samples |
| `camMat` | mat3 | Camera orientation matrix |
| `config` | DoFConfig | DoF configuration |
| `time` | float | Current time for temporal jitter |

#### Returns
Offset vector to add to ray origin (in world space).

#### Algorithm: Fibonacci Spiral Sampling

Uses the golden angle to distribute samples evenly across the aperture:

```
golden_angle = π(3 - √5) ≈ 2.39996
```

Each sample is placed at:
- Angle: `i * golden_angle + temporal_offset`
- Radius: `√(i / n) * aperture * polygon_scale`

The square root ensures uniform area distribution (not clustering at center).

#### Implementation

```glsl
vec3 getDoFOffset(int sampleIndex, int sampleCount, mat3 camMat, 
                  DoFConfig config, float time) {
    // First sample is always at center (clean reference)
    if (sampleIndex == 0 || sampleCount <= 1) {
        return vec3(0.0);
    }
    
    float goldenAngle = 2.399963229728653;
    
    // Temporal jitter rotates pattern each frame
    float temporalOffset = 0.0;
    if (config.temporalSpeed > 0.0) {
        temporalOffset = fract(time * config.temporalSpeed) * 
                         goldenAngle * config.temporalAmount;
    }
    
    float angle = float(sampleIndex) * goldenAngle + temporalOffset;
    float radius = sqrt(float(sampleIndex) / float(sampleCount)) * config.aperture;
    
    // Shape into polygon
    radius *= polygonRadius(angle, config.blades, config.bladeRotation);
    
    // Return offset in camera space
    return camMat * vec3(cos(angle) * radius, sin(angle) * radius, 0.0);
}
```

#### Simplified Overload

```glsl
vec3 getDoFOffset(int sampleIndex, int sampleCount, mat3 camMat, 
                  float aperture, float time)
```

Uses default config with custom aperture.

---

## Transmission Functions

### estimateTransmissionThickness

Estimates how thick a transparent object is along a refraction ray.

```glsl
float estimateTransmissionThickness(vec3 startPos, vec3 dir)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `startPos` | vec3 | Starting point inside surface |
| `dir` | vec3 | Normalized refraction direction |

#### Algorithm

March forward while still inside the object (negative SDF values):

```glsl
float estimateTransmissionThickness(vec3 startPos, vec3 dir) {
    float thickness = 0.0;
    vec3 pos = startPos;
    
    for (int i = 0; i < 6; i++) {
        float d = getDist(pos).w;
        if (d > 0.002) break;  // Exited object
        
        float stepSize = clamp(-d, 0.02, 0.12);
        pos += dir * stepSize;
        thickness += stepSize;
    }
    return thickness;
}
```

**Complexity:** O(n) - Up to 6 SDF evaluations.

---

### marchThroughObject

Marches through a transmissive object to find the exit point.

```glsl
void marchThroughObject(vec3 ro, vec3 rd, float ior, 
                        out vec3 exitPos, out vec3 exitNormal, out float thickness)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `ro` | vec3 | Starting point inside object |
| `rd` | vec3 | Refracted ray direction |
| `ior` | float | Index of refraction |

#### Outputs
| Name | Type | Description |
|------|------|-------------|
| `exitPos` | vec3 | Position where ray exits object |
| `exitNormal` | vec3 | Surface normal at exit (pointing outward) |
| `thickness` | float | Total distance traveled through object |

#### Algorithm

Continue marching while SDF is negative (inside object):

```glsl
void marchThroughObject(vec3 ro, vec3 rd, float ior, 
                        out vec3 exitPos, out vec3 exitNormal, out float thickness) {
    thickness = 0.0;
    vec3 pos = ro;
    
    for (int i = 0; i < 64; i++) {
        float d = getDist(pos).w;
        
        if (d > MIN_DIST * 2.0) {
            // Found exit
            exitPos = pos;
            exitNormal = getNorm(pos);
            return;
        }
        
        float step = max(abs(d), 0.01);
        pos += rd * step;
        thickness += step;
        
        if (thickness > 2.0) break;  // Safety limit
    }
    
    exitPos = pos;
    exitNormal = getNorm(pos);
}
```

---

### traceRefraction

Complete refraction trace through a transparent object.

```glsl
vec3 traceRefraction(vec3 hitPos, vec3 rd, vec3 normal, float ior, 
                     vec3 tint, vec3 bgCol)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `hitPos` | vec3 | Entry point on surface |
| `rd` | vec3 | Incoming ray direction |
| `normal` | vec3 | Surface normal (pointing outward) |
| `ior` | float | Index of refraction |
| `tint` | vec3 | Material tint color |
| `bgCol` | vec3 | Background color fallback |

#### Returns
Color seen through the transparent object.

#### Physics: Snell's Law

Refraction follows Snell's Law:
```
n₁ sin(θ₁) = n₂ sin(θ₂)
```

GLSL's `refract()` function implements this:
```glsl
vec3 T = refract(rd, normal, n1/n2);
```

#### Total Internal Reflection

When light travels from dense to less dense medium at steep angles, it reflects instead of refracting. We detect this when `refract()` returns zero and fall back to reflection:

```glsl
if (dot(exitDir, exitDir) < 0.0001) {
    exitDir = reflect(T, -exitNormal);  // Total internal reflection
}
```

#### Beer-Lambert Absorption

Light traveling through colored material loses intensity exponentially:
```
I = I₀ * e^(-α * d)
```

Where α is the absorption coefficient (higher for colors NOT in the material):

```glsl
vec3 absorption = exp(-(vec3(1.0) - tint) * thickness * 2.5);
```

#### Implementation

```glsl
vec3 traceRefraction(vec3 hitPos, vec3 rd, vec3 normal, float ior, 
                     vec3 tint, vec3 bgCol) {
    // Entry refraction
    float eta = 1.0 / max(ior, 1.001);
    vec3 T = refract(rd, normal, eta);
    
    if (dot(T, T) < 0.0001) return bgCol;  // Total internal reflection
    
    // Step inside object
    vec3 entryPos = hitPos - normal * (MIN_DIST * 10.0);
    
    // March through to find exit
    vec3 exitPos, exitNormal;
    float thickness;
    marchThroughObject(entryPos, T, ior, exitPos, exitNormal, thickness);
    
    // Exit refraction (invert eta)
    float etaExit = max(ior, 1.001);
    vec3 exitDir = refract(T, -exitNormal, etaExit);
    
    if (dot(exitDir, exitDir) < 0.0001) {
        exitDir = reflect(T, -exitNormal);  // TIR fallback
    }
    
    // Trace what's behind the object
    vec3 exitRo = exitPos + exitNormal * (MIN_DIST * 10.0);
    vec4 behindScene = map(exitRo, exitDir);
    
    vec3 behindColor = bgCol;
    if (behindScene.w < farClip) {
        vec3 behindHit = exitRo + exitDir * behindScene.w;
        vec3 behindNorm = getNorm(behindHit);
        behindColor = getLight(behindHit, exitDir, behindScene.rgb, behindNorm) 
                    + gMaterial.emission;
    }
    
    // Apply absorption
    vec3 absorption = exp(-(vec3(1.0) - tint) * thickness * 2.5);
    vec3 tintedColor = behindColor * absorption;
    tintedColor = mix(tintedColor, tintedColor * tint, 0.3);
    
    return tintedColor;
}
```

---

## Surface Shading

### shadeHit

Complete surface shading with lighting, Fresnel, reflections, and refraction.

```glsl
vec3 shadeHit(vec3 hitPos, vec3 rd, vec3 material, vec3 bgCol)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `hitPos` | vec3 | Surface hit position |
| `rd` | vec3 | Ray direction |
| `material` | vec3 | Surface albedo |
| `bgCol` | vec3 | Background color |

#### Fresnel Calculation (Schlick Approximation)

The Fresnel effect describes how surfaces become more reflective at glancing angles:

```
F = F₀ + (1 - F₀)(1 - cos θ)⁵
```

Where:
- `F₀` is the reflectivity at normal incidence
- `θ` is the angle between surface normal and view direction

**F₀ Values:**
| Material Type | F₀ |
|--------------|-----|
| Dielectric (plastic) | 0.04 |
| Metal | 0.9 |
| Iridescent | 0.15 |

#### Implementation

```glsl
vec3 shadeHit(vec3 hitPos, vec3 rd, vec3 material, vec3 bgCol) {
    vec3 normals = getNorm(hitPos);
    
    // Cache material properties
    float metallic = gMaterial.metallic;
    float roughness = gMaterial.roughness;
    vec3 emission = gMaterial.emission;
    float transmission = gMaterial.transmission;
    float ior = gMaterial.ior;
    float iridescence = gMaterial.iridescence;
    
    // Apply iridescence
    if (iridescence > 0.0) {
        float NdotV = max(dot(normals, -rd), 0.0);
        vec3 iriColor = getIridescentColor(NdotV, material);
        material = mix(material, iriColor, iridescence);
    }
    
    // Fresnel (Schlick approximation)
    float F0 = mix(0.04, 0.9, metallic);
    F0 = mix(F0, 0.15, iridescence);
    float cosTheta = max(dot(normals, -rd), 0.0);
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
    
    // Roughness reduces reflection
    float roughnessDampen = (1.0 - roughness) * (1.0 - roughness);
    float reflectionStrength = fresnel * roughnessDampen;
    
    // Direct lighting
    float lightingFactor = (1.0 - reflectionStrength * 0.7) * 
                          (1.0 - emissionStrength) * 
                          (transmission > 0.2 ? 0.0 : 1.0);
    vec3 col = getLight(hitPos, rd, material, normals) * lightingFactor;
    
    // Reflections
    if (roughness < 0.85 && emissionStrength < 0.5) {
        vec3 R = reflect(rd, normals);
        vec3 reflColor = getFirstReflection(hitPos + normals * MIN_DIST * 4.0, R, bgCol);
        vec3 reflTint = mix(vec3(1.0), material, max(metallic * 0.5, iridescence * 0.6));
        col += reflColor * reflTint * reflectionStrength;
    }
    
    // Refraction
    if (transmission > 0.0 && ior > 1.0) {
        vec3 refrColor = traceRefraction(hitPos, rd, normals, ior, material, bgCol);
        float fresnelTrans = 1.0 - reflectionStrength;
        col = refrColor * fresnelTrans + reflectionCol * reflectionStrength * 0.7;
    }
    
    col += emission;
    return col;
}
```

---

## Lens Effects

### getLensFlare

Simple lens flare effect.

```glsl
vec3 getLensFlare(vec3 rd, vec3 ro, vec3 lightPos, vec3 lightCol, float expo)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `rd` | vec3 | Ray direction |
| `ro` | vec3 | Ray origin |
| `lightPos` | vec3 | Light source position |
| `lightCol` | vec3 | Flare color |
| `expo` | float | Falloff exponent (higher = tighter) |

#### Implementation

```glsl
vec3 getLensFlare(vec3 rd, vec3 ro, vec3 lightPos, vec3 lightCol, float expo) {
    float f = clamp(dot(rd, normalize(lightPos - ro)), 0.0, 1.0);
    f = pow(f, expo);
    return f * lightCol;
}
```

The flare intensity is based on how closely the view direction aligns with the light direction, raised to a power for falloff control.

---

## Usage Example: Complete Render Loop

```glsl
void main() {
    // Setup camera
    vec3 ro = camPos;
    vec3 ta = vec3(0.0);
    mat3 camMat = getCameraMatrix(ro, ta);
    
    // Generate ray
    vec2 uv = (gl_FragCoord.xy - 0.5 * iResolution.xy) / iResolution.y;
    vec3 rd = normalize(camMat * vec3(uv, 1.0));
    
    // Background
    vec3 bgCol = vec3(0.1, 0.12, 0.15);
    
    // Raymarch
    vec4 scene = map(ro, rd);
    float dist = scene.w;
    
    vec3 col;
    if (dist < farClip) {
        vec3 hitPos = ro + rd * dist;
        col = shadeHit(hitPos, rd, scene.rgb, bgCol);
    } else {
        col = bgCol;
    }
    
    // Post-processing
    getPostProcessing(col, rd, ro, bgCol, dist, uv);
    
    fragColor = vec4(col, 1.0);
}
```

---

## Depth of Field Usage

```glsl
vec3 accumulatedColor = vec3(0.0);
int dofSamples = 16;
DoFConfig dofConfig = getDefaultDoFConfig();
dofConfig.aperture = 0.15;

for (int i = 0; i < dofSamples; i++) {
    vec3 offset = getDoFOffset(i, dofSamples, camMat, dofConfig, iTime);
    vec3 sampleRo = ro + offset;
    
    // Adjust ray direction to converge at focus distance
    float focusDist = 2.0;
    vec3 focusPoint = ro + rd * focusDist;
    vec3 sampleRd = normalize(focusPoint - sampleRo);
    
    // Render sample
    vec4 scene = map(sampleRo, sampleRd);
    vec3 sampleCol = renderScene(sampleRo, sampleRd, scene);
    
    accumulatedColor += sampleCol;
}

vec3 finalColor = accumulatedColor / float(dofSamples);
```
