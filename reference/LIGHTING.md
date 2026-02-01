# Lighting Reference

This module provides physically-inspired lighting calculations including diffuse, specular, shadows, ambient occlusion, and advanced effects like subsurface scattering.

**File:** `modules/lighting.glsl`

---

## Surface Normals

### getNorm

Calculates the surface normal at a hit position using the gradient of the SDF.

```glsl
vec3 getNorm(vec3 hitPos)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `hitPos` | vec3 | Position on the surface |

#### Mathematical Derivation

The normal to an implicit surface `f(p) = 0` is the gradient `∇f`:

```
N = normalize(∇f) = normalize(∂f/∂x, ∂f/∂y, ∂f/∂z)
```

We approximate partial derivatives using central differences:

```
∂f/∂x ≈ (f(p + εx̂) - f(p - εx̂)) / 2ε
```

For efficiency, we use a very small `ε = 0.00001`:

#### Implementation

```glsl
vec3 getNorm(vec3 hitPos) {
    vec2 eps = vec2(0.00001, 0.0);
    float shiftX = getDist(hitPos + eps.xyy).w - getDist(hitPos - eps.xyy).w;
    float shiftY = getDist(hitPos + eps.yxy).w - getDist(hitPos - eps.yxy).w;
    float shiftZ = getDist(hitPos + eps.yyx).w - getDist(hitPos - eps.yyx).w;
    return normalize(vec3(shiftX, shiftY, shiftZ));
}
```

#### Complexity
**O(6)** - Six SDF evaluations for central differences.

#### Usage
```glsl
vec3 hitPos = ro + rd * hitDist;
vec3 normal = getNorm(hitPos);
```

---

## Main Lighting Function

### getLight

Primary lighting calculation with PBR metallic workflow support.

```glsl
vec3 getLight(vec3 hitPos, vec3 rd, vec3 mate, vec3 normals)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `hitPos` | vec3 | Surface hit position |
| `rd` | vec3 | Ray direction (view vector) |
| `mate` | vec3 | Surface albedo color |
| `normals` | vec3 | Surface normal |

#### Lighting Model

The function implements a combination of:

1. **Lambertian Diffuse**: `N · L`
2. **Blinn-Phong Specular**: `(N · H)^power`
3. **Metallic Workflow**: Metals reduce diffuse and tint specular
4. **Ambient Occlusion**: Contact shadows in crevices
5. **Soft Shadows**: Material-aware shadow casting
6. **Subsurface Scattering**: Light transmission through thin materials
7. **Emissive Lighting**: Illumination from glowing objects

#### Mathematical Components

**Diffuse (Lambertian)**:
```
diffuse = max(N · L, 0) * albedo * (1 - metallic * 0.9)
```

**Specular (Blinn-Phong)**:
```
H = normalize(L + V)
specPower = mix(64.0, 4.0, roughness)  // Sharp to blurry
specular = (N · H)^specPower * specColor
```

Where `specColor` is white for dielectrics, albedo-tinted for metals.

**Combined Output**:
```
color = (diffuse + specular) * lightIntensity * shadow + ambient
```

#### Implementation Highlights

```glsl
// Diffuse: metals have reduced diffuse
float NdotL = max(-dot(lightDir, normals), 0.0);
vec3 diffuse = mate * NdotL * (1.0 - metallic * 0.9);

// Specular: roughness controls sharpness
float NdotH = max(dot(normals, halfVec), 0.0);
float specPower = mix(64.0, 4.0, roughness);
float spec = pow(NdotH, specPower);

// Shadow softness varies with roughness
float shadowSoftness = mix(16.0, 4.0, roughness);
```

#### Complexity
**O(n)** where n depends on enabled features (AO iterations, SSS samples, emissive count).

---

## Shadow Functions

### getSimpleShadow

Basic soft shadow calculation without caustics.

```glsl
float getSimpleShadow(vec3 hitPos, vec3 rd, float k)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `hitPos` | vec3 | Surface position (shadow origin) |
| `rd` | vec3 | Direction toward light source |
| `k` | float | Shadow softness (higher = softer penumbra) |

#### Mathematical Basis

Soft shadows use the **penumbra estimation** technique:

```
shadow = min(shadow, k * d / h)
```

Where:
- `d` is distance to nearest surface along shadow ray
- `h` is distance traveled along ray
- `k` controls penumbra width

A near-miss creates soft edges proportional to how close we passed an occluder.

#### Implementation

```glsl
float getSimpleShadow(vec3 hitPos, vec3 rd, float k) {
    float sha = 1.0;
    for (float h = 0.01; h < 12.0; ) {
        float d = getDist(hitPos + rd * h).w;
        
        // Handle special materials (emissive, transparent, SSS)
        // ...
        
        if (d < MIN_DIST) return 0.0;  // Full shadow
        
        sha = min(sha, k * d / h);  // Penumbra estimation
        h += d;
    }
    return sha;
}
```

#### Typical k Values
| k Value | Effect |
|---------|--------|
| 2-4 | Very soft, diffuse shadows |
| 8-16 | Medium shadows |
| 32+ | Hard, crisp shadows |

---

### getColoredShadow

Advanced shadow calculation with caustics from transparent materials.

```glsl
vec3 getColoredShadow(vec3 hitPos, vec3 rd, float k)
```

#### Returns
RGB shadow color where:
- `vec3(1.0)` = No shadow (full light)
- `vec3(0.0)` = Full shadow (no light)
- Colored values = Caustic tinting from transparent objects

#### Caustic Calculation

When light passes through transparent material:

1. **Beer-Lambert Absorption**:
   ```glsl
   vec3 absorptionCoeff = vec3(1.0) - hitAlbedo;
   float thickness = 0.25 * (hitIOR - 1.0);
   vec3 causticTint = exp(-absorptionCoeff * thickness * 5.0);
   ```

2. **Light Focusing** (curved surface concentration):
   ```glsl
   float curvature = abs(dot(hitNormal, rd));
   float focusing = 1.0 + (1.0 - curvature) * 0.8 * hitTransmission;
   ```

3. **Chromatic Aberration** (prismatic color splitting):
   ```glsl
   float chromatic = (hitIOR - 1.33) * 0.2;
   shadowColor.r *= 1.0 + chromatic;
   shadowColor.b *= 1.0 - chromatic;
   ```

#### SSS Shadow Handling

Subsurface scattering materials cast soft, tinted shadows:

```glsl
// Estimate thickness through SSS object
float sssThickness = marchThroughSSS(samplePos, rd);

// Thickness-driven transmission
float trans = exp(-sssThickness * 6.0);
vec3 tint = exp(-absorptionCoeff * sssThickness * 5.0);

shadowColor *= mix(vec3(1.0), tint, 0.9);
sha *= mix(0.12, 0.85, trans);
```

---

## Ambient Occlusion

### getAmbientOcclusion

Approximates contact shadows where geometry is close together.

```glsl
float getAmbientOcclusion(vec3 hitPos, vec3 normal)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `hitPos` | vec3 | Surface position |
| `normal` | vec3 | Surface normal |

#### Algorithm

Samples the SDF at increasing distances along the normal. If the SDF returns a smaller distance than expected, nearby geometry is occluding:

```
For each sample i:
    expected_dist = 0.01 + 0.04 * i/4
    actual_dist = SDF(hitPos + normal * expected_dist)
    occlusion += (expected_dist - actual_dist) * weight
```

#### Implementation

```glsl
float getAmbientOcclusion(vec3 hitPos, vec3 normal) {
    float occ = 0.0;
    float sca = 1.0;  // Weight decreases for distant samples
    
    for (int i = 0; i < 5; i++) {
        float h = 0.01 + 0.04 * float(i) / 4.0;
        float d = getDist(hitPos + normal * h).w;
        occ += (h - d) * sca;
        sca *= 0.5;  // Halve weight each iteration
    }
    
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}
```

#### Complexity
**O(5)** - Five SDF evaluations per pixel.

---

## Point and Spot Lights

### getPointLight

Calculates illumination from an omni-directional point light.

```glsl
vec3 getPointLight(vec3 hitPos, vec3 lightPos, vec3 normals, vec3 rd, 
                   vec3 refRd, vec3 lightCol, vec3 mate)
```

#### Attenuation

Uses inverse-square falloff (physically correct):

```glsl
float dist = length(hitPos - lightPos);
float att = 1.0 / (dist * dist);
```

### getSpotLight

Calculates illumination from a directional cone light.

```glsl
vec3 getSpotLight(vec3 hitPos, vec3 spotPos, vec3 spotDir, vec3 normals,
                  vec3 rd, vec3 spotCol, float innerAngle, float outerAngle)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `innerAngle` | float | Full-intensity cone angle (radians) |
| `outerAngle` | float | Edge of light cone (radians) |

#### Cone Attenuation

```glsl
float cosAngle = dot(-lightDir, spotDir);
float cosInner = cos(innerAngle);
float cosOuter = cos(outerAngle);
float spotAtt = clamp((cosAngle - cosOuter) / (cosInner - cosOuter), 0.0, 1.0);
spotAtt = spotAtt * spotAtt;  // Smooth quadratic falloff
```

---

## Sky Light

### getSkyLight

Ambient environmental lighting from above.

```glsl
vec3 getSkyLight(vec3 hitPos, vec3 normals, float occ, vec3 mate, 
                 vec3 refRd, vec3 col)
```

#### Implementation

```glsl
// Hemisphere diffuse (upward-facing surfaces receive more sky light)
float dif = sqrt(clamp(normals.y * 0.5 + 0.5, 0.0, 1.0));

// Fresnel reflection
float fresnel = pow(clamp(1.0 - dot(normals, -refRd), 0.0, 1.0), 5.0) * 0.95 + 0.05;

// Sky color
vec3 skyCol = vec3(0.7, 0.9, 1.0) * 0.4;

col += dif * skyCol * occ * mate * (1.0 - fresnel);
```

---

## Subsurface Scattering

Implemented within `getLight()` when `RM_ENABLE_SSS` is enabled.

### Physical Basis

SSS simulates light entering a translucent material, scattering internally, and exiting at a different point. Key phenomena:

1. **Back-lighting**: Light visible through thin areas from behind
2. **Wrap Lighting**: Soft light bleeding around edges
3. **Rim Scattering**: Glowing edges when backlit
4. **Absorption**: Colored tinting based on material (Beer-Lambert law)

### Algorithm

```glsl
// 1. Estimate local thickness by sampling SDF behind surface
float thickness = 0.0;
for (int i = 1; i <= 4; i++) {
    float sampleDist = 0.02 * float(i);
    float d = getDist(hitPos - normals * sampleDist).w;
    thickness += max(0.0, -d);  // Accumulate negative distances (inside)
}

// 2. Calculate absorption (Beer-Lambert)
vec3 absorptionCoeff = vec3(1.0) - subsurfaceCol;
vec3 absorption = exp(-absorptionCoeff * thickness * 4.0);

// 3. Back-lighting contribution
float NdotL_back = max(dot(lightDir, normals), 0.0);
float backlit = NdotL_back * pow(1.0 - thickness, 2.0);

// 4. Wrap lighting for soft edges
float wrap = max(0.0, (dot(-lightDir, normals) + 0.5) / 1.5);

// 5. View-dependent rim scattering
float NdotV = max(dot(normals, -rd), 0.0);
float rimScatter = pow(1.0 - NdotV, 3.0) * 0.3;

// 6. Combine and apply
float scatter = (wrap * 0.5 + backlit * 1.5 + rimScatter) * (1.0 - thickness * 0.7);
col += subsurfaceCol * scatter * subsurface * lightIntensity;
```

---

## Reflections

### getFirstReflection

Traces a single reflection bounce for mirror/metallic surfaces.

```glsl
vec3 getFirstReflection(vec3 ro, vec3 rd, vec3 bgCol)
```

Performs a full raymarch along the reflection ray and applies lighting to the hit point.

---

## Camera Matrix

### getCameraMatrix

Constructs a view matrix for orienting rays.

```glsl
mat3 getCameraMatrix(vec3 ro, vec3 ta)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `ro` | vec3 | Camera position (ray origin) |
| `ta` | vec3 | Look-at target point |

#### Implementation

```glsl
mat3 getCameraMatrix(vec3 ro, vec3 ta) {
    vec3 a = normalize(ta - ro);            // Forward (Z)
    vec3 b = cross(a, vec3(0.0, 1.0, 0.0)); // Right (X)
    vec3 c = cross(b, a);                    // Up (Y)
    return mat3(b, c, a);
}
```

Returns a 3x3 matrix where columns are the camera's right, up, and forward vectors.
