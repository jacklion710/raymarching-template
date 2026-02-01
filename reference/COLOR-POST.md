# Color & Post-Processing Reference

This module provides color space transformations, tone mapping, and cinematic post-processing effects.

**Files:** `modules/color.glsl`, `modules/post.glsl`, `modules/fog.glsl`

---

## Tone Mapping

### toneMapping (ACES Filmic)

Industry-standard tone mapping that preserves color and contrast.

```glsl
vec3 toneMapping(vec3 col)
```

#### Purpose

HDR (High Dynamic Range) rendering produces color values exceeding the 0-1 display range. Tone mapping compresses these values while preserving perceptual quality.

#### Mathematical Basis

ACES (Academy Color Encoding System) uses a fitted curve that:
1. Transforms from sRGB to ACES color space
2. Applies an S-curve response (RRT + ODT fit)
3. Transforms back to sRGB

The curve provides:
- Gentle highlight rolloff (no harsh clipping)
- Preserved shadow detail
- Pleasing color desaturation at high intensities

#### Implementation

```glsl
vec3 toneMapping(vec3 col) {
    // sRGB → ACES
    mat3 inputMat = mat3(
        0.59719, 0.07600, 0.02840,
        0.35458, 0.90834, 0.13383,
        0.04823, 0.01566, 0.83777
    );
    
    // ACES → sRGB
    mat3 outputMat = mat3(
        1.60475, -0.10208, -0.00327,
        -0.53108,  1.10813, -0.07276,
        -0.07367, -0.00605,  1.07602
    );
    
    col = inputMat * col;
    
    // RRT and ODT fit
    vec3 a = col * (col + 0.0245786) - 0.000090537;
    vec3 b = col * (0.983729 * col + 0.4329510) + 0.238081;
    col = a / b;
    
    col = outputMat * col;
    
    return clamp(col, 0.0, 1.0);
}
```

**Complexity:** O(1)

---

### gammaCorrection

Converts from linear to sRGB gamma space for display.

```glsl
vec3 gammaCorrection(vec3 col)
```

#### Purpose

Displays expect sRGB gamma-encoded values. Linear rendering must be gamma-corrected before output.

#### Mathematical Basis

Approximate sRGB transfer function:
```
sRGB ≈ linear^(1/2.2)
```

#### Implementation

```glsl
vec3 gammaCorrection(vec3 col) {
    return pow(max(col, vec3(0.0)), vec3(1.0/2.2));
}
```

**Note:** Applied LAST in the pipeline, after all other effects.

---

### exposure

Photographic exposure control.

```glsl
vec3 exposure(vec3 col, float exposure)
```

#### Mathematical Basis

Simulates camera sensor response:
```
output = 1 - e^(-input × exposure)
```

This creates a natural rolloff at high intensities.

#### Implementation

```glsl
vec3 exposure(vec3 col, float exposure) {
    return vec3(1.0) - exp(-max(col, vec3(0.0)) * exposure);
}
```

#### Typical Values
| Exposure | Effect |
|----------|--------|
| 0.5 | Darker, preserves highlights |
| 1.0 | Neutral |
| 2.0 | Brighter, more compressed |
| 4.0 | Very bright, washed out |

---

## Color Adjustments

### contrast

Adjusts image contrast around middle gray.

```glsl
vec3 contrast(vec3 col, float contrast)
```

#### Mathematical Basis

Linear contrast adjustment pivoting at 0.5:
```
output = (input - 0.5) × contrast + 0.5
```

#### Implementation

```glsl
vec3 contrast(vec3 col, float contrast) {
    return (col - 0.5) * contrast + 0.5;
}
```

#### Values
| Contrast | Effect |
|----------|--------|
| 0.5 | Low contrast (flat, foggy) |
| 1.0 | No change |
| 1.5 | High contrast (punchy) |

---

### saturation

Adjusts color saturation.

```glsl
vec3 saturation(vec3 col, float saturation)
```

#### Mathematical Basis

Blends between grayscale and original color:
```
luminance = 0.2126R + 0.7152G + 0.0722B  (Rec. 709)
output = mix(luminance, input, saturation)
```

#### Implementation

```glsl
vec3 saturation(vec3 col, float saturation) {
    return mix(vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))), col, saturation);
}
```

#### Values
| Saturation | Effect |
|------------|--------|
| 0.0 | Grayscale |
| 1.0 | No change |
| 1.5 | Vibrant colors |

---

### hueShift

Rotates colors around the color wheel.

```glsl
vec3 hueShift(vec3 col, float hueShift)
```

#### Mathematical Basis

1. Convert RGB to YIQ (luminance + chrominance)
2. Rotate the IQ (chrominance) components
3. Convert back to RGB

YIQ separates brightness (Y) from color (I, Q), allowing hue rotation without affecting luminance.

#### Implementation

```glsl
vec3 hueShift(vec3 col, float hueShift) {
    // RGB → YIQ
    float Y = dot(col, vec3(0.299, 0.587, 0.114));
    float I = dot(col, vec3(0.596, -0.274, -0.322));
    float Q = dot(col, vec3(0.211, -0.523, 0.312));
    
    // Rotate IQ
    float cosA = cos(hueShift);
    float sinA = sin(hueShift);
    float I2 = I * cosA - Q * sinA;
    float Q2 = I * sinA + Q * cosA;
    
    // YIQ → RGB
    return vec3(
        Y + 0.956 * I2 + 0.621 * Q2,
        Y - 0.272 * I2 - 0.647 * Q2,
        Y - 1.105 * I2 + 1.702 * Q2
    );
}
```

#### Values
| Hue Shift | Effect |
|-----------|--------|
| 0 | No change |
| π/3 | Shift by 60° |
| π | Complementary colors |
| 2π | Full rotation (same as 0) |

---

### brightness

Simple additive brightness.

```glsl
vec3 brightness(vec3 col, float brightness)
```

#### Implementation

```glsl
vec3 brightness(vec3 col, float brightness) {
    return col + vec3(brightness);
}
```

---

### colorTemperature

Adjusts white balance (warm/cool).

```glsl
vec3 colorTemperature(vec3 col, float temperature)
```

#### Parameters
| temperature | Effect |
|-------------|--------|
| -1.0 | Cool (blue tint) |
| 0.0 | Neutral |
| +1.0 | Warm (orange tint) |

#### Implementation

```glsl
vec3 colorTemperature(vec3 col, float temperature) {
    vec3 warm = vec3(1.0 + temperature * 0.1, 1.0, 1.0 - temperature * 0.15);
    vec3 cool = vec3(1.0 + temperature * 0.1, 1.0 + temperature * 0.02, 1.0 - temperature * 0.1);
    return col * (temperature > 0.0 ? warm : cool);
}
```

---

## Advanced Color Grading

### liftGammaGain

Professional three-way color correction.

```glsl
vec3 liftGammaGain(vec3 col, vec3 lift, vec3 gamma, vec3 gain)
```

#### Parameters
| Parameter | Affects | Description |
|-----------|---------|-------------|
| `lift` | Shadows | Added to dark areas |
| `gamma` | Midtones | Power curve adjustment |
| `gain` | Highlights | Multiplied with bright areas |

#### Mathematical Basis

```
output = ((input × gain) + lift)^(1/gamma)
```

#### Implementation

```glsl
vec3 liftGammaGain(vec3 col, vec3 lift, vec3 gamma, vec3 gain) {
    col = col * gain + lift;
    col = pow(max(col, vec3(0.0)), 1.0 / gamma);
    return col;
}
```

#### Preset Examples

```glsl
// Teal and Orange (blockbuster movie look)
col = liftGammaGain(col, 
    vec3(-0.02, 0.01, 0.04),   // Blue shadows
    vec3(0.95, 1.0, 1.05),     // Neutral midtones
    vec3(1.1, 0.98, 0.85)      // Orange highlights
);

// Cool Moody
col = liftGammaGain(col,
    vec3(0.0, 0.02, 0.05),     // Cool shadows
    vec3(0.98, 0.98, 1.02),    // Slightly cool mids
    vec3(0.95, 0.97, 1.0)      // Cool highlights
);

// Golden Hour
col = liftGammaGain(col,
    vec3(0.02, 0.01, -0.02),   // Warm shadows
    vec3(1.02, 1.0, 0.95),     // Warm mids
    vec3(1.1, 1.0, 0.88)       // Golden highlights
);
```

---

### splitToning

Applies different tints to shadows and highlights.

```glsl
vec3 splitToning(vec3 col, vec3 shadowTint, vec3 highlightTint, float balance)
```

#### Parameters
| Name | Description |
|------|-------------|
| `shadowTint` | Color multiplied into dark areas |
| `highlightTint` | Color added to bright areas |
| `balance` | Crossover luminance (0-1, typically 0.5) |

#### Implementation

```glsl
vec3 splitToning(vec3 col, vec3 shadowTint, vec3 highlightTint, float balance) {
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    float shadowWeight = smoothstep(balance, 0.0, luma);
    float highlightWeight = smoothstep(balance, 1.0, luma);
    col = mix(col, col * shadowTint, shadowWeight * 0.5);
    col = mix(col, col + highlightTint * 0.2, highlightWeight);
    return col;
}
```

---

## Visual Effects

### vignette

Darkens edges for cinematic focus.

```glsl
vec3 vignette(vec3 col, vec2 uv, float strength, float softness)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `uv` | vec2 | Screen coords relative to center (-0.5 to 0.5) |
| `strength` | float | Vignette intensity (0-1) |
| `softness` | float | Falloff gradient (higher = softer) |

#### Implementation

```glsl
vec3 vignette(vec3 col, vec2 uv, float strength, float softness) {
    float dist = length(uv);
    float vig = 1.0 - smoothstep(1.0 - softness, 1.0, dist * (1.0 + strength));
    return col * vig;
}
```

---

### filmGrain

Adds organic noise texture.

```glsl
vec3 filmGrain(vec3 col, vec2 uv, float time, float amount)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `time` | float | Animation time (varies grain pattern) |
| `amount` | float | Grain intensity (0.03 = subtle, 0.1 = heavy) |

#### Implementation

```glsl
vec3 filmGrain(vec3 col, vec2 uv, float time, float amount) {
    float noise = fract(sin(dot(uv + fract(time), vec2(12.9898, 78.233))) * 43758.5453);
    noise = (noise - 0.5) * amount;
    return col + vec3(noise);
}
```

---

### chromaticAberration

Creates RGB fringing at screen edges.

```glsl
vec3 chromaticAberration(vec3 col, vec2 uv, float strength)
```

#### Physical Basis

Real lenses refract different wavelengths at slightly different angles. This creates color separation at edges.

**Note:** True CA requires texture sampling. This is a single-pass approximation.

#### Implementation

```glsl
vec3 chromaticAberration(vec3 col, vec2 uv, float strength) {
    vec2 center = vec2(0.5);
    vec2 dir = uv - center;
    float dist = length(dir);
    float falloff = dist * dist * 2.0;
    
    float redAmount = falloff * strength * 0.15;
    float blueAmount = falloff * strength * 0.1;
    
    col.r += redAmount;
    col.b += blueAmount;
    col.r -= blueAmount * 0.05;
    col.b -= redAmount * 0.08;
    
    return clamp(col, 0.0, 1.0);
}
```

---

### dither

Reduces color banding in gradients.

```glsl
vec3 dither(vec3 col, vec2 uv, float bitDepth)
```

#### Purpose

8-bit displays have limited precision, causing visible banding in smooth gradients. Dithering adds noise before quantization to perceptually smooth the gradient.

#### Implementation

```glsl
vec3 dither(vec3 col, vec2 uv, float bitDepth) {
    float levels = pow(2.0, bitDepth);
    
    // Triangular dither noise (better than uniform)
    float noise1 = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
    float noise2 = fract(sin(dot(uv + 0.5, vec2(12.9898, 78.233))) * 43758.5453);
    float triNoise = (noise1 + noise2 - 1.0) / levels;
    
    return col + vec3(triNoise);
}
```

---

### localContrast

Sharpening approximation via local contrast enhancement.

```glsl
vec3 localContrast(vec3 col, float amount)
```

**Note:** True sharpening requires multi-pass rendering. This approximation enhances perceived detail.

#### Implementation

```glsl
vec3 localContrast(vec3 col, float amount) {
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    vec3 enhanced = col + (col - vec3(luma)) * amount * 0.5;
    enhanced = mix(enhanced, enhanced * enhanced * (3.0 - 2.0 * enhanced), amount * 0.3);
    return clamp(enhanced, 0.0, 1.0);
}
```

---

## Fog

**File:** `modules/fog.glsl`

### distanceFog

Linear distance-based fog.

```glsl
vec3 distanceFog(vec3 col, vec3 bgCol, float dist)
```

#### Implementation

```glsl
vec3 distanceFog(vec3 col, vec3 bgCol, float dist) {
    return mix(col, bgCol, dist / farClip);
}
```

Objects fade to background color linearly with distance.

---

## Post-Processing Pipeline

**File:** `modules/post.glsl`

### getPostProcessing

Complete post-processing chain.

```glsl
void getPostProcessing(inout vec3 col, vec3 rd, vec3 ro, vec3 bgCol, float dist, vec2 uv)
```

#### Pipeline Order

1. **Pre-tonemapping (linear space)**
   - Emissive glow aura
   - Lens flare
   - Distance fog
   - Exposure (optional)

2. **Tone mapping**
   - ACES filmic

3. **Post-tonemapping (display space)**
   - Contrast
   - Saturation
   - Brightness
   - Color temperature
   - Split toning
   - Lift/Gamma/Gain
   - Local contrast
   - Chromatic aberration (optional)
   - Vignette
   - Film grain

4. **Final output**
   - Dithering
   - Gamma correction

#### Implementation

```glsl
void getPostProcessing(inout vec3 col, vec3 rd, vec3 ro, vec3 bgCol, float dist, vec2 uv) {
    // PRE-TONEMAPPING
    col += getEmissiveGlow(ro, rd, dist);
    col += getLensFlare(rd, ro, lightPos, vec3(1.0, 0.75, 0.7), 10.0) * 0.5;
    col = distanceFog(col, bgCol, dist);
    
    // TONE MAPPING
    col = toneMapping(col);
    
    // POST-TONEMAPPING
    col = contrast(col, 1.1);
    col = saturation(col, 1.15);
    col = brightness(col, 0.02);
    col = colorTemperature(col, 0.5);
    col = splitToning(col, vec3(0.9, 0.95, 1.1), vec3(1.1, 1.0, 0.9), 0.75);
    col = liftGammaGain(col, vec3(0.0), vec3(1.0), vec3(1.0));
    col = localContrast(col, 0.7);
    
    vec2 vigUV = uv - 0.5;
    col = vignette(col, vigUV, 0.4, 0.7);
    col = filmGrain(col, uv, iTime, 0.03);
    
    // FINAL OUTPUT
    col = dither(col, uv * 1000.0, 8.0);
    col = gammaCorrection(col);
}
```

---

## Emissive Glow

### getEmissiveGlow

Calculates atmospheric glow from emissive objects.

```glsl
vec3 getEmissiveGlow(vec3 ro, vec3 rd, float sceneDepth)
```

#### Algorithm

For each emissive source:
1. Find closest point on ray to emissive center
2. Calculate distance to emissive
3. Apply soft falloff based on emissive radius
4. Accumulate colored glow

#### Implementation

```glsl
vec3 getEmissiveGlow(vec3 ro, vec3 rd, float sceneDepth) {
    vec3 totalGlow = vec3(0.0);
    
    for (int i = 0; i < NUM_EMISSIVES; i++) {
        vec4 source = getEmissiveSource(i);
        vec4 props = getEmissiveProperties(i);
        
        vec3 emissivePos = source.xyz;
        float emissiveRadius = source.w;
        vec3 emissiveCol = props.xyz * props.w * 0.15;
        
        // Closest point on ray
        vec3 toEmissive = emissivePos - ro;
        float t = clamp(dot(toEmissive, rd), 0.0, sceneDepth);
        vec3 closestPoint = ro + rd * t;
        float distToEmissive = length(closestPoint - emissivePos);
        
        // Soft glow falloff
        float glowRadius = emissiveRadius * 4.0;
        float glow = 1.0 - smoothstep(0.0, glowRadius, distToEmissive);
        glow = glow * glow;
        
        totalGlow += emissiveCol * glow * 0.2;
    }
    
    return totalGlow;
}
```
