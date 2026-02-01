# HG_SDF Library Reference

Mercury's comprehensive GLSL library for building signed distance bounds. This library provides primitives, domain operators, and combination functions.

**File:** `modules/hg_sdf.glsl`  
**Source:** [mercury.sexy/hg_sdf](https://mercury.sexy/hg_sdf)  
**License:** MIT or CC-BY-NC-4.0

---

## Constants and Helpers

### Mathematical Constants

```glsl
#define PI 3.14159265
#define TAU (2*PI)           // Full circle
#define PHI (sqrt(5)*0.5 + 0.5)  // Golden ratio ≈ 1.618
```

### saturate

Clamps value to [0, 1] range.

```glsl
#define saturate(x) clamp(x, 0, 1)
```

Often optimized by GPU hardware.

---

### sgn

Sign function that never returns 0.

```glsl
float sgn(float x)  // Returns -1 or 1
vec2 sgn(vec2 v)    // Per-component
```

Unlike GLSL's `sign()` which returns 0 for input 0, `sgn()` always returns ±1.

---

### square

Square a value.

```glsl
float square(float x)
vec2 square(vec2 x)
vec3 square(vec3 x)
```

---

### lengthSqr

Squared length (avoids sqrt).

```glsl
float lengthSqr(vec3 x)
```

Useful for comparisons where you don't need the actual length.

---

### vmax / vmin

Maximum/minimum element of a vector.

```glsl
float vmax(vec2 v)
float vmax(vec3 v)
float vmax(vec4 v)
float vmin(vec2 v)
float vmin(vec3 v)
float vmin(vec4 v)
```

---

## Primitive Distance Functions

### Naming Convention

All primitives begin with `f` (for "field") and take position `p` as first argument.

---

### fSphere

```glsl
float fSphere(vec3 p, float r)
```

Sphere centered at origin with radius `r`.

---

### fPlane

```glsl
float fPlane(vec3 p, vec3 n, float distanceFromOrigin)
```

Infinite plane with normal `n` at specified distance from origin.

---

### fBox

```glsl
float fBox(vec3 p, vec3 b)
```

Box centered at origin with half-extents `b`. Correct distance to corners.

### fBoxCheap

```glsl
float fBoxCheap(vec3 p, vec3 b)
```

Faster box that overestimates distance at corners. Use for bounding volumes.

### fBox2 / fBox2Cheap

2D versions (infinite along Z).

```glsl
float fBox2(vec2 p, vec2 b)
float fBox2Cheap(vec2 p, vec2 b)
```

---

### fCorner

```glsl
float fCorner(vec2 p)
```

Endless 90-degree corner in 2D.

---

### fCylinder

```glsl
float fCylinder(vec3 p, float r, float height)
```

Cylinder standing on XZ plane, centered at origin.

---

### fCapsule

Cylinder with hemispherical caps.

```glsl
float fCapsule(vec3 p, float r, float c)
```

**Parameters:**
- `r`: Radius
- `c`: Half-height (cap centers at ±c)

**Alternative form:**

```glsl
float fCapsule(vec3 p, vec3 a, vec3 b, float r)
```

Capsule between points `a` and `b` with radius `r`.

---

### fTorus

```glsl
float fTorus(vec3 p, float smallRadius, float largeRadius)
```

Torus (donut) in XZ plane.

---

### fCircle

```glsl
float fCircle(vec3 p, float r)
```

Circle line (ring) in XZ plane. Subtract a value to make a flat disc.

---

### fDisc

```glsl
float fDisc(vec3 p, float r)
```

Flat circular disc with no thickness. Subtract value for rounded edge.

---

### fCone

```glsl
float fCone(vec3 p, float radius, float height)
```

Cone pointing up (Y+), base at origin. Correct distances to tip and base.

---

### fBlob

```glsl
float fBlob(vec3 p)
```

Organic blob shape. **Not a correct distance bound** - use carefully.

---

### fHexagonCircumcircle / fHexagonIncircle

```glsl
float fHexagonCircumcircle(vec3 p, vec2 h)  // h = (radius, height)
float fHexagonIncircle(vec3 p, vec2 h)
```

Hexagonal prisms. Circumcircle variant touches corners, incircle variant touches edges.

---

## Generalized Distance Functions (GDF)

Based on Akleman and Chen's paper. These create complex polyhedra using dot products with predefined direction vectors.

### GDFVectors

19 predefined vectors for constructing various solids:
- Indices 0-2: Axis-aligned
- Indices 3-6: Body diagonals
- Indices 7-12: Icosahedral directions (part 1)
- Indices 13-18: Icosahedral directions (part 2)

### fGDF

```glsl
float fGDF(vec3 p, float r, float e, int begin, int end)  // With exponent
float fGDF(vec3 p, float r, int begin, int end)           // Sharp edges
```

The exponent `e` controls bulging:
- `e = 1`: Sharp edges
- `e = 2`: Rounded
- Higher: More spherical

### Specific Polyhedra

```glsl
float fOctahedron(vec3 p, float r)
float fOctahedron(vec3 p, float r, float e)

float fDodecahedron(vec3 p, float r)
float fDodecahedron(vec3 p, float r, float e)

float fIcosahedron(vec3 p, float r)
float fIcosahedron(vec3 p, float r, float e)

float fTruncatedOctahedron(vec3 p, float r)
float fTruncatedOctahedron(vec3 p, float r, float e)

float fTruncatedIcosahedron(vec3 p, float r)  // Soccer ball shape
float fTruncatedIcosahedron(vec3 p, float r, float e)
```

---

## Domain Manipulation

See [Domain Operations](./DOMAIN-OPS.md) for detailed coverage of:
- `pR`, `pR45` - Rotation
- `pMod1`, `pModMirror1`, `pModSingle1`, `pModInterval1` - 1D repetition
- `pModPolar` - Radial repetition
- `pMod2`, `pModMirror2`, `pModGrid2` - 2D repetition
- `pMod3` - 3D repetition
- `pMirror`, `pMirrorOctant` - Mirroring
- `pReflect` - Plane reflection

---

## Object Combination Operators

### Philosophy

These operators create smooth transitions at intersections while maintaining correct distance bounds (unlike naive smooth minimum functions).

**Key insight:** At right-angle intersections, the two distances form a 2D coordinate system. We can evaluate any 2D shape in this space to create the desired edge profile.

---

### Chamfer Operations

45-degree chamfered edges.

```glsl
float fOpUnionChamfer(float a, float b, float r)
float fOpIntersectionChamfer(float a, float b, float r)
float fOpDifferenceChamfer(float a, float b, float r)
```

**Parameter `r`:** Size of the chamfer (diagonal of the square cut).

#### Usage

```glsl
float box = fBox(p, vec3(1.0));
float sphere = fSphere(p - vec3(1.0, 0.0, 0.0), 0.5);
float chamfered = fOpUnionChamfer(box, sphere, 0.1);
```

---

### Round Operations

Quarter-circle rounded edges (fillets).

```glsl
float fOpUnionRound(float a, float b, float r)
float fOpIntersectionRound(float a, float b, float r)
float fOpDifferenceRound(float a, float b, float r)
```

**Parameter `r`:** Radius of the rounding.

#### Usage

```glsl
// Rounded union
float rounded = fOpUnionRound(box, sphere, 0.2);

// Fillet (rounded intersection)
float fillet = fOpIntersectionRound(floor, wall, 0.1);
```

---

### Columns Operations

Creates n-1 circular columns at 45-degree intersections.

```glsl
float fOpUnionColumns(float a, float b, float r, float n)
float fOpIntersectionColumns(float a, float b, float r, float n)
float fOpDifferenceColumns(float a, float b, float r, float n)
```

**Parameters:**
- `r`: Column region size
- `n`: Number of columns (n-1 actual columns)

---

### Stairs Operations

Creates staircase pattern at intersections.

```glsl
float fOpUnionStairs(float a, float b, float r, float n)
float fOpIntersectionStairs(float a, float b, float r, float n)
float fOpDifferenceStairs(float a, float b, float r, float n)
```

**Parameters:**
- `r`: Total stair depth
- `n`: Number of steps (n-1 actual steps)

---

### Soft Union

More Lipschitz-continuous at acute angles than standard smooth min.

```glsl
float fOpUnionSoft(float a, float b, float r)
```

From MediaMolecule (Alex Evans). Better for steep angle intersections.

---

### Special Operators

#### fOpPipe

Creates a cylindrical pipe along the intersection.

```glsl
float fOpPipe(float a, float b, float r)
```

No objects remain - only the pipe. Not a boolean operator.

#### fOpEngrave

V-shaped engraving where objects intersect.

```glsl
float fOpEngrave(float a, float b, float r)
```

First object gets the engraving at intersection with second.

#### fOpGroove

Carpenter-style groove cut.

```glsl
float fOpGroove(float a, float b, float ra, float rb)
```

**Parameters:**
- `ra`: Groove depth
- `rb`: Groove width

#### fOpTongue

Carpenter-style tongue (protrusion).

```glsl
float fOpTongue(float a, float b, float ra, float rb)
```

---

## Best Practices

### Lipschitz Continuity

The library is designed to maintain distance bound correctness:

> "Stay Lipschitz continuous. That means: don't have any distance gradient larger than 1."

- Don't multiply distances to "fix" violations
- The operators preserve bounds when surfaces intersect at ~90°
- Accuracy degrades for parallel or acute-angle surfaces

### Building Geometry

1. **Use few primitives** - Combine with operators
2. **Multiply by repeating space** - Not by looping SDF calls
3. **Build local coordinate systems** - At intersections, use the two distances as 2D coordinates

### Material Assignment

The library recommends:

> "Write a material ID, distance, and local coordinate into globals when distance is smallest. Evaluate material at the end for shading."

This matches our `gMaterial` pattern.

---

## Example: Complex Object

```glsl
float complexObject(vec3 p) {
    // Base rounded box
    float box = fBox(p, vec3(0.8, 0.3, 0.5)) - 0.05;
    
    // Add cylindrical protrusions
    vec3 q = p;
    pModPolar(q.xz, 4.0);
    q.x -= 0.6;
    float cylinders = fCylinder(q.xzy, 0.15, 0.4);
    
    // Round union
    float body = fOpUnionRound(box, cylinders, 0.1);
    
    // Carve center hole
    float hole = fCylinder(p.xzy, 0.25, 1.0);
    body = fOpDifferenceRound(body, hole, 0.05);
    
    // Add decorative groove
    float groove = fTorus(p, 0.02, 0.5);
    body = fOpGroove(body, groove, 0.03, 0.04);
    
    return body;
}
```
