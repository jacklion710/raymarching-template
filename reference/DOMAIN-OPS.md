# Domain Operations Reference

Domain operations transform the coordinate space before evaluating SDFs. This enables infinite repetition, mirroring, rotation, and other spatial manipulations without duplicating geometry.

**Files:** `modules/domain-repetition.glsl`, `modules/rotate.glsl`, `modules/hg_sdf.glsl`

---

## Core Concept

Instead of moving objects, we transform the sampling position:

```glsl
// Move object to (1, 0, 0):
float d = SDFsphere(pos - vec3(1.0, 0.0, 0.0), vec3(0.0), 0.5);

// Equivalently, move the space:
vec3 q = pos - vec3(1.0, 0.0, 0.0);
float d = SDFsphere(q, vec3(0.0), 0.5);
```

This becomes powerful when we apply operations like `mod()` to create infinite copies.

---

## Finite Domain Repetition

### opRepeatFinite

Repeats space in a bounded region.

**File:** `modules/domain-repetition.glsl`

```glsl
vec3 opRepeatFinite(vec3 p, vec3 cellSize, vec3 halfCount, vec3 origin)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `p` | vec3 | World-space position |
| `cellSize` | vec3 | Size of each repeating cell |
| `halfCount` | vec3 | Half the number of repetitions per axis |
| `origin` | vec3 | Center of the repetition grid |

#### Returns
Transformed position within the nearest cell.

#### Mathematical Basis

1. Offset position relative to origin: `q = p - origin`
2. Calculate cell index: `cellIndex = round(q / cellSize)`
3. Clamp to bounds: `cellIndex = clamp(cellIndex, -halfCount, halfCount)`
4. Return position within cell: `q - cellSize * cellIndex + origin`

#### Implementation

```glsl
vec3 opRepeatFinite(vec3 p, vec3 cellSize, vec3 halfCount, vec3 origin) {
    vec3 q = p - origin;
    vec3 cellIndex = clamp(round(q / cellSize), -halfCount, halfCount);
    return q - cellSize * cellIndex + origin;
}
```

**Complexity:** O(1)

#### Usage

```glsl
// 5x1x5 grid of spheres (halfCount of 2 = 5 total: -2,-1,0,1,2)
vec3 q = opRepeatFinite(pos, vec3(1.0), vec3(2.0, 0.0, 2.0), vec3(0.0));
float d = SDFsphere(q, vec3(0.0), 0.3);
```

---

## Rotation

### getRotationMatrix

Creates a rotation matrix around an arbitrary axis.

**File:** `modules/rotate.glsl`

```glsl
mat3 getRotationMatrix(vec3 v, float angle)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `v` | vec3 | Rotation axis (should be normalized) |
| `angle` | float | Rotation angle in radians |

#### Mathematical Derivation (Rodrigues' Formula)

For rotation by angle θ around unit axis v:

```
R = I cos(θ) + (1 - cos(θ)) v ⊗ v + sin(θ) [v]×
```

Where:
- `I` is identity matrix
- `v ⊗ v` is outer product (v * vᵀ)
- `[v]×` is skew-symmetric cross-product matrix

#### Implementation

```glsl
mat3 getRotationMatrix(vec3 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    float ic = 1.0 - c;
    
    return mat3(
        v.x*v.x*ic + c,       v.y*v.x*ic - s*v.z,   v.z*v.x*ic + s*v.y,
        v.x*v.y*ic + s*v.z,   v.y*v.y*ic + c,       v.z*v.y*ic - s*v.x,
        v.x*v.z*ic - s*v.y,   v.y*v.z*ic + s*v.x,   v.z*v.z*ic + c
    );
}
```

**Complexity:** O(1)

#### Usage

```glsl
// Rotate around Y axis
mat3 rotY = getRotationMatrix(vec3(0.0, 1.0, 0.0), iTime);
vec3 rotatedPos = rotY * pos;
float d = SDFbox(rotatedPos, vec3(0.0), vec3(0.5));

// Rotate around diagonal axis
mat3 rotDiag = getRotationMatrix(normalize(vec3(1.0, 1.0, 0.0)), iTime * 0.5);
```

---

## HG_SDF Domain Operators

The Mercury HG_SDF library provides extensive domain manipulation functions.

**File:** `modules/hg_sdf.glsl`

### Naming Convention

- `pSomething`: Modifies position `p` in place
- Functions return cell index when applicable

---

### pR - 2D Rotation

Rotates a 2D slice of space.

```glsl
void pR(inout vec2 p, float a)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `p` | vec2 | Position components to rotate (e.g., `p.xz`) |
| `a` | float | Rotation angle in radians |

#### Usage

```glsl
// Rotate around Y axis (in XZ plane)
pR(pos.xz, iTime);
float d = SDFbox(pos, vec3(0.0), vec3(0.5));

// Rotate around Z axis (in XY plane)
pR(pos.xy, 0.785);  // 45 degrees
```

**Note:** "Rotate X towards Z" means X+ rotates toward Z+.

---

### pR45 - 45-Degree Rotation

Optimized rotation by exactly 45 degrees.

```glsl
void pR45(inout vec2 p)
```

Faster than `pR()` when you only need 45° (avoids trig functions).

---

### pMod1 - 1D Infinite Repetition

Repeats space along one axis infinitely.

```glsl
float pMod1(inout float p, float size)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `p` | float | Position component (modified in place) |
| `size` | float | Cell size |

#### Returns
Cell index (integer indicating which copy).

#### Implementation

```glsl
float pMod1(inout float p, float size) {
    float halfsize = size * 0.5;
    float c = floor((p + halfsize) / size);
    p = mod(p + halfsize, size) - halfsize;
    return c;
}
```

#### Usage

```glsl
// Infinite row of spheres along X
float cellX = pMod1(pos.x, 2.0);  // 2 units apart
float d = SDFsphere(pos, vec3(0.0), 0.5);

// Use cell index for variation
float d = SDFsphere(pos, vec3(0.0), 0.3 + 0.2 * sin(cellX));
```

---

### pModMirror1 - Mirrored 1D Repetition

Repeats and mirrors alternating cells so edges match.

```glsl
float pModMirror1(inout float p, float size)
```

Useful for patterns that need continuity at cell boundaries.

---

### pModSingle1 - Positive-Only Repetition

Only repeats in the positive direction.

```glsl
float pModSingle1(inout float p, float size)
```

Objects in negative space remain unchanged—useful for ground planes with repeated objects above.

---

### pModInterval1 - Bounded 1D Repetition

Repeats only within a range of cells.

```glsl
float pModInterval1(inout float p, float size, float start, float stop)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `start` | float | First cell index |
| `stop` | float | Last cell index |

#### Usage

```glsl
// Only 5 copies: indices 0, 1, 2, 3, 4
float cell = pModInterval1(pos.x, 1.0, 0.0, 4.0);
```

---

### pModPolar - Radial Repetition

Repeats around the origin in a circular pattern.

```glsl
float pModPolar(inout vec2 p, float repetitions)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `p` | vec2 | Position in the plane (modified in place) |
| `repetitions` | float | Number of copies around the circle |

#### Usage

```glsl
// 8 spheres in a circle
pModPolar(pos.xz, 8.0);
pos.x -= 2.0;  // Move out from center
float d = SDFsphere(pos, vec3(0.0), 0.3);
```

---

### pMod2 - 2D Grid Repetition

Repeats in a 2D grid pattern.

```glsl
vec2 pMod2(inout vec2 p, vec2 size)
```

#### Returns
Cell indices as `vec2(cellX, cellY)`.

#### Usage

```glsl
// Grid of pillars
vec2 cell = pMod2(pos.xz, vec2(3.0, 3.0));
float d = SDFbox(pos, vec3(0.0), vec3(0.3, 10.0, 0.3));
```

---

### pMod3 - 3D Grid Repetition

Full 3D space repetition.

```glsl
vec3 pMod3(inout vec3 p, vec3 size)
```

#### Usage

```glsl
// Infinite 3D lattice of spheres
vec3 cell = pMod3(pos, vec3(2.0));
float d = SDFsphere(pos, vec3(0.0), 0.5);
```

---

### pMirror - Axis Mirror

Folds space at a plane, creating symmetry.

```glsl
float pMirror(inout float p, float dist)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `p` | float | Position component |
| `dist` | float | Distance of mirror plane from origin |

#### Returns
Sign indicating which side the original point was on.

#### Usage

```glsl
// Mirror across X=0 plane
pMirror(pos.x, 0.0);
// Now only need to define half the scene

// Mirror with offset
pMirror(pos.x, 1.0);  // Mirror plane at x=1
```

---

### pReflect - Plane Reflection

Reflects space across an arbitrary plane.

```glsl
float pReflect(inout vec3 p, vec3 planeNormal, float offset)
```

#### Parameters
| Name | Type | Description |
|------|------|-------------|
| `planeNormal` | vec3 | Normal of reflection plane (normalized) |
| `offset` | float | Distance of plane from origin along normal |

---

## Combining Operators

### Pattern: Infinite Grid with Variation

```glsl
vec4 scene(vec3 pos) {
    vec2 cell = pMod2(pos.xz, vec2(2.0));
    
    // Use cell index for pseudo-random variation
    float h = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
    float height = 0.5 + h * 2.0;
    
    return vec4(vec3(h, 0.5, 1.0 - h), SDFbox(pos, vec3(0.0), vec3(0.4, height, 0.4)));
}
```

### Pattern: Radial Array with Central Object

```glsl
vec4 scene(vec3 pos) {
    // Central sphere
    vec4 center = vec4(vec3(1.0, 0.0, 0.0), SDFsphere(pos, vec3(0.0), 0.5));
    
    // Ring of smaller spheres
    vec3 q = pos;
    pModPolar(q.xz, 12.0);  // 12 copies
    q.x -= 2.0;              // Move out from center
    vec4 ring = vec4(vec3(0.0, 0.0, 1.0), SDFsphere(q, vec3(0.0), 0.2));
    
    return getMin(center, ring);
}
```

### Pattern: Mirrored Symmetry

```glsl
vec4 scene(vec3 pos) {
    // 8-way symmetry (mirror X, Y, Z and diagonals)
    pos = abs(pos);  // Mirror all axes
    
    // Define once, get 8 copies
    float d = SDFsphere(pos - vec3(1.0), vec3(0.0), 0.3);
    return vec4(vec3(0.5), d);
}
```

---

## Performance Tips

### Distance Correction for Scaling

When scaling space, multiply the returned distance:

```glsl
vec3 q = pos * 2.0;  // Scale down (objects appear 2x smaller)
float d = SDFsphere(q, vec3(0.0), 0.5);
d /= 2.0;  // Correct the distance
```

### Avoid Nested Repetitions

Nested `pMod` calls can create overlapping geometry and performance issues. Instead, use 2D/3D repetition operators.

### Cell Index Usage

Cell indices enable:
- Per-copy variation (color, size, rotation)
- Frustum culling (skip distant cells)
- LOD (simpler shapes for far cells)

```glsl
vec2 cell = pMod2(pos.xz, vec2(5.0));
float distToCell = length(cell * 5.0);  // Approximate world distance

// Skip very far cells
if (distToCell > 50.0) {
    return vec4(0.0, 0.0, 0.0, distToCell - 2.5);
}
```
