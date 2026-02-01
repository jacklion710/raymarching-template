# SDF Primitives Reference

Signed Distance Functions (SDFs) are the foundation of raymarching. Each function returns the shortest Euclidean distance from a sample point to the surface of a shape.

## Core Concepts

### What Makes a Valid SDF

A proper SDF must satisfy the **Lipschitz condition**: the gradient magnitude should be exactly 1 everywhere (or at most 1 for a distance bound). This means:
- The distance changes by exactly 1 unit per unit of movement
- Raymarching can safely step by the returned distance without overshooting

### Distance Semantics

```
distance > 0  →  point is OUTSIDE the shape
distance < 0  →  point is INSIDE the shape  
distance = 0  →  point is ON the surface
```

---

## Sphere

**File:** `modules/sdf.glsl`

```glsl
float SDFsphere(vec3 p, vec3 c, float ra)
```

### Parameters
| Name | Type | Description |
|------|------|-------------|
| `p` | vec3 | World-space position being sampled |
| `c` | vec3 | Sphere center in world-space |
| `ra` | float | Sphere radius |

### Mathematical Derivation

The sphere is defined as all points at exactly distance `r` from center `c`:

```
|p - c| = r
```

Therefore, the signed distance is simply:

```
SDF(p) = |p - c| - r
```

This subtracts the radius from the distance to center:
- Points outside: `|p - c| > r` → positive
- Points inside: `|p - c| < r` → negative

### Implementation

```glsl
float SDFsphere(vec3 p, vec3 c, float ra) {
    return length(p - c) - ra;
}
```

### Complexity
**O(1)** - Single vector subtraction and length calculation.

### Usage Example

```glsl
// Sphere centered at origin with radius 0.5
float d = SDFsphere(pos, vec3(0.0), 0.5);

// Animated bouncing sphere
vec3 spherePos = vec3(0.0, 0.3 + sin(iTime) * 0.2, 0.0);
float d = SDFsphere(pos, spherePos, 0.25);
```

---

## Box (Axis-Aligned)

**File:** `modules/sdf.glsl`

```glsl
float SDFbox(vec3 p, vec3 c, vec3 ra)
```

### Parameters
| Name | Type | Description |
|------|------|-------------|
| `p` | vec3 | World-space position being sampled |
| `c` | vec3 | Box center in world-space |
| `ra` | vec3 | Box half-extents (half-size per axis) |

### Mathematical Derivation

For an axis-aligned box centered at origin with half-extents `b`:

1. **Fold to positive octant**: Use `abs(p)` since the box is symmetric
2. **Compute per-axis distances**: `q = abs(p) - b`
3. **Combine distances**:
   - Outside corner: Euclidean distance to corner
   - Outside face: Distance to nearest face
   - Inside: Maximum distance to any face (negative)

The formula combines these cases:

```
SDF(p) = length(max(q, 0)) + min(max(q.x, q.y, q.z), 0)
```

Where:
- `length(max(q, 0))` handles outside regions (positive components)
- `min(max(q.x, q.y, q.z), 0)` handles inside (all components negative)

### Implementation

```glsl
float SDFbox(vec3 p, vec3 c, vec3 ra) {
    vec3 d = abs(p - c) - ra;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}
```

### Complexity
**O(1)** - Constant operations regardless of box size.

### Usage Example

```glsl
// Unit cube centered at origin
float d = SDFbox(pos, vec3(0.0), vec3(0.5));

// Flat ground plane (very thin box)
float ground = SDFbox(pos, vec3(0.0, -0.5, 0.0), vec3(10.0, 0.01, 10.0));

// Non-uniform rectangular prism
float brick = SDFbox(pos, vec3(0.0), vec3(0.4, 0.2, 0.1));
```

### Rounding the Box

To create rounded edges, subtract the corner radius from the half-extents and add it to the final distance:

```glsl
float roundedBox(vec3 p, vec3 c, vec3 ra, float cornerRadius) {
    return SDFbox(p, c, ra - cornerRadius) - cornerRadius;
}
```

---

## Composite Object Example

**File:** `modules/sdf.glsl`

```glsl
float obj1(vec3 pos, vec3 c, vec3 ra)
```

Demonstrates combining primitives using boolean operations.

### Parameters
| Name | Type | Description |
|------|------|-------------|
| `pos` | vec3 | World-space position being sampled |
| `c` | vec3 | Object center in world-space |
| `ra` | vec3 | Object scale (per-axis extent) |

### Implementation Analysis

```glsl
float obj1(vec3 pos, vec3 c, vec3 ra) {
    float cube = SDFbox(pos, c, vec3(0.14) * ra) - 0.01;  // Rounded cube
    float sphere = SDFsphere(pos, c, 0.18 * ra.x);        // Carving sphere
    float sphere2 = SDFsphere(pos, c, 0.2 * ra.x);        // Bounding sphere
    
    float closest = max(cube, -sphere);   // Subtract sphere from cube
    return max(closest, sphere2);          // Intersect with outer sphere
}
```

### Boolean Operations Used

1. **Subtraction** (`max(a, -b)`): Carves sphere out of cube
2. **Intersection** (`max(a, b)`): Limits result to outer sphere

### Complexity
**O(1)** - Fixed number of primitive evaluations.

---

## Best Practices

### Centering Objects

Always design SDFs centered at the origin, then translate:

```glsl
// Good: Translate in the call
float d = SDFsphere(pos - objectPosition, vec3(0.0), radius);

// Alternative: Pass center parameter
float d = SDFsphere(pos, objectPosition, radius);
```

### Scaling SDFs

When scaling an SDF, you must also scale the returned distance:

```glsl
float scaledSphere(vec3 p, float scale) {
    return SDFsphere(p / scale, vec3(0.0), 1.0) * scale;
}
```

Failing to multiply by scale breaks the Lipschitz condition.

### Combining SDFs

See [Modifiers](./MODIFIERS.md) for union, intersection, and smooth blending operations.

---

## Common Pitfalls

### 1. Non-uniform Scaling
Scaling axes differently breaks exact distances:

```glsl
// WRONG: Creates invalid SDF
float d = SDFsphere(p * vec3(1.0, 2.0, 1.0), vec3(0.0), 1.0);

// Use an ellipsoid SDF instead for non-uniform shapes
```

### 2. Forgetting to Offset Center
```glsl
// WRONG: Always at origin
float d = SDFsphere(pos, vec3(0.0), 0.5);

// RIGHT: Object at desired location
float d = SDFsphere(pos, objectCenter, 0.5);
```

### 3. Incorrect Boolean Operations
```glsl
// Union (combine shapes): min(a, b)
// Intersection (overlap only): max(a, b)
// Subtraction (carve b from a): max(a, -b)
```
