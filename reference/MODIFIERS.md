# Modifiers Reference

SDF modifiers combine, blend, and transform signed distance fields. These are essential building blocks for creating complex geometry from simple primitives.

**File:** `modules/modifiers.glsl`

---

## Boolean Operations

### Conceptual Foundation

Boolean operations on SDFs correspond to set operations:
- **Union** (A ∪ B): Combine shapes → `min(a, b)`
- **Intersection** (A ∩ B): Overlap only → `max(a, b)`
- **Subtraction** (A - B): Carve B from A → `max(a, -b)`

The key insight is that `min()` selects the nearest surface (union), while `max()` requires both conditions to be satisfied (intersection).

---

## Minimum/Maximum Functions

### getMin

Hard union of two SDFs with material.

```glsl
vec4 getMin(vec4 a, vec4 b)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `a` | vec4 | First SDF: `(albedo.rgb, distance)` |
| `b` | vec4 | Second SDF: `(albedo.rgb, distance)` |

#### Returns
The closer of the two surfaces with its material.

#### Implementation

```glsl
vec4 getMin(vec4 a, vec4 b) {
    return (a.w < b.w) ? a : b;
}
```

**Complexity:** O(1)

#### Usage

```glsl
vec4 sphere = vec4(vec3(1.0, 0.0, 0.0), SDFsphere(pos, vec3(0.0), 0.5));
vec4 box = vec4(vec3(0.0, 0.0, 1.0), SDFbox(pos, vec3(1.0, 0.0, 0.0), vec3(0.3)));
vec4 scene = getMin(sphere, box);  // Union of red sphere and blue box
```

---

### getMax

Hard intersection of two SDFs with material.

```glsl
vec4 getMax(vec4 a, vec4 b)
```

#### Implementation

```glsl
vec4 getMax(vec4 a, vec4 b) {
    return (a.w > b.w) ? a : b;
}
```

#### Usage

```glsl
// Sphere carved into cube shape (cube intersected with sphere)
vec4 sphere = vec4(color, SDFsphere(pos, vec3(0.0), 0.8));
vec4 cube = vec4(color, SDFbox(pos, vec3(0.0), vec3(0.5)));
vec4 result = getMax(sphere, cube);  // Only where both are inside
```

---

## Smooth Minimum (Blending)

### smin

Smooth minimum for float distances.

```glsl
float smin(float a, float b, float k)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `a` | float | First distance |
| `b` | float | Second distance |
| `k` | float | Smoothing factor (larger = smoother blend) |

#### Mathematical Derivation

The polynomial smooth minimum creates a smooth blend region where `|a - b| < k`:

```
h = max(k - |a - b|, 0) / k
smin = min(a, b) - h² * k / 4
```

This subtracts a parabolic "bulge" in the blend region, creating smooth organic transitions.

#### Implementation

```glsl
float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * (1.0 / 4.0);
}
```

**Complexity:** O(1)

#### Visual Effect of k Values

| k Value | Effect |
|---------|--------|
| 0.0 | No blending (same as `min()`) |
| 0.1 | Subtle rounding at intersection |
| 0.3 | Moderate organic blend |
| 0.5+ | Strong melting/merging effect |

#### Usage

```glsl
float blob1 = SDFsphere(pos, vec3(-0.3, 0.0, 0.0), 0.4);
float blob2 = SDFsphere(pos, vec3(0.3, 0.0, 0.0), 0.4);
float merged = smin(blob1, blob2, 0.3);  // Organic blob union
```

---

### getSmin

Smooth minimum with material blending.

```glsl
vec4 getSmin(vec4 a, vec4 b, float k)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `a` | vec4 | First SDF: `(albedo.rgb, distance)` |
| `b` | vec4 | Second SDF: `(albedo.rgb, distance)` |
| `k` | float | Smoothing factor |

#### Material Blending

The blend factor `m` is used to interpolate both distance AND color:

```glsl
vec4 getSmin(vec4 a, vec4 b, float k) {
    float h = max(k - abs(a.w - b.w), 0.0) / k;
    float m = h * h * h * 0.5;          // Blend factor
    float s = m * k * (1.0 / 3.0);      // Distance offset
    
    return (a.w < b.w) 
        ? vec4(mix(a.rgb, b.rgb, vec3(m)), a.w - s)
        : vec4(mix(b.rgb, a.rgb, vec3(m)), b.w - s);
}
```

This creates smooth color gradients at blend regions—useful for organic creatures, metaballs, etc.

#### Usage

```glsl
vec4 redSphere = vec4(vec3(1.0, 0.0, 0.0), SDFsphere(pos, vec3(-0.3, 0.0, 0.0), 0.4));
vec4 blueSphere = vec4(vec3(0.0, 0.0, 1.0), SDFsphere(pos, vec3(0.3, 0.0, 0.0), 0.4));
vec4 merged = getSmin(redSphere, blueSphere, 0.3);
// Result: Smoothly blended shape transitioning from red to blue
```

---

## Smooth Maximum (Intersection)

### smax

Smooth maximum for float distances.

```glsl
float smax(float a, float b, float k)
```

#### Mathematical Derivation

The smooth maximum mirrors smooth minimum but adds instead of subtracts:

```
h = max(k - |a - b|, 0) / k
smax = max(a, b) + h² * k / 4
```

#### Implementation

```glsl
float smax(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return max(a, b) + h * h * k * (1.0 / 4.0);
}
```

#### Usage

```glsl
// Rounded intersection (fillet)
float box = SDFbox(pos, vec3(0.0), vec3(0.5));
float sphere = SDFsphere(pos, vec3(0.0), 0.7);
float rounded = smax(box, sphere, 0.1);  // Box with rounded edges
```

---

### getSmax

Smooth maximum with material blending.

```glsl
vec4 getSmax(vec4 a, vec4 b, float k)
```

#### Implementation

```glsl
vec4 getSmax(vec4 a, vec4 b, float k) {
    float kSafe = max(k, 0.00001);
    float h = clamp(0.5 + 0.5 * (a.w - b.w) / kSafe, 0.0, 1.0);
    float d = mix(b.w, a.w, h) + kSafe * h * (1.0 - h);
    vec3 albedo = mix(b.rgb, a.rgb, h);
    return vec4(albedo, d);
}
```

---

## Scene Result Helpers

For cleaner scene construction with full material support.

### SceneResult Structure

```glsl
struct SceneResult {
    float dist;
    Material mat;
};
```

### sceneResult

Create a SceneResult.

```glsl
SceneResult sceneResult(float dist, Material mat)
```

### sceneMin

Union of two SceneResults.

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

Smooth union with material interpolation.

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

## Common Patterns

### Subtraction (Carving)

To carve shape B from shape A:

```glsl
float result = max(a, -b);

// Or with materials:
vec4 carved = getMax(a, vec4(b.rgb, -b.w));
```

**Example: Hollow sphere**
```glsl
float outer = SDFsphere(pos, vec3(0.0), 1.0);
float inner = SDFsphere(pos, vec3(0.0), 0.8);
float hollow = max(outer, -inner);  // Shell
```

### Smooth Subtraction

```glsl
float smoothCarve(float a, float b, float k) {
    return -smin(-a, b, k);
}
```

### Onion (Shell)

Create a shell of thickness `t`:

```glsl
float shell = abs(sdf) - t;
```

**Example:**
```glsl
float sphere = SDFsphere(pos, vec3(0.0), 1.0);
float sphereShell = abs(sphere) - 0.05;  // 0.05 thick shell
```

### Rounding

Add rounding to any SDF:

```glsl
float rounded = sdf - radius;
```

**Example:**
```glsl
float box = SDFbox(pos, vec3(0.0), vec3(0.5 - 0.1));
float roundedBox = box - 0.1;  // 0.1 radius rounding
```

### Displacement

Add noise or pattern to surface:

```glsl
float displaced = sdf + displacement(pos);
```

**Example:**
```glsl
float sphere = SDFsphere(pos, vec3(0.0), 1.0);
float bumpy = sphere + sin(pos.x * 20.0) * sin(pos.y * 20.0) * sin(pos.z * 20.0) * 0.02;
```

**Warning:** Displacement can break the Lipschitz condition if too large.

---

## Multiple Object Scenes

### Chain Pattern

```glsl
vec4 scene(vec3 pos) {
    vec4 result = vec4(0.0, 0.0, 0.0, 1e10);  // Start with infinity
    
    result = getMin(result, object1(pos));
    result = getMin(result, object2(pos));
    result = getSmin(result, object3(pos), 0.2);  // Blend this one
    result = getMax(result, vec4(color, -cutterSdf));  // Subtract
    
    return result;
}
```

### Hierarchical Pattern

```glsl
vec4 scene(vec3 pos) {
    // Build sub-assemblies
    vec4 head = getSmin(skull(pos), jaw(pos), 0.1);
    vec4 body = getSmin(torso(pos), limbs(pos), 0.15);
    
    // Combine assemblies
    return getSmin(head, body, 0.2);
}
```

---

## Performance Considerations

### Lipschitz Continuity

All smooth blending operations maintain the Lipschitz condition (gradient ≤ 1) when used correctly. This ensures raymarching remains stable.

### k Value Guidelines

- **Too small k:** Visual artifacts, no visible blending
- **Too large k:** Performance issues (larger blend regions), incorrect distance bounds
- **Sweet spot:** Typically 0.1 - 0.5 times the smallest object radius

### Optimization

For complex scenes, consider spatial partitioning:

```glsl
vec4 scene(vec3 pos) {
    // Early-out for distant regions
    if (pos.y > 10.0) return vec4(0.0, 0.0, 0.0, pos.y - 5.0);
    
    // Full scene evaluation
    return fullScene(pos);
}
```
