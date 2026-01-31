# Architecture

This document describes the structure and organization of the raymarching template.

## Directory Structure

```
raymarching-template/
├── README.md                    # Project overview and quick start
├── TODO.md                      # Development roadmap
├── globals.glsl                 # Shared constants, uniforms, feature flags
├── raymarching-template.jxs     # Jitter shader manifest (include order)
├── raymarching-template.maxpat  # Max/MSP patch for runtime control
│
├── docs/                        # Documentation
│   ├── ARCHITECTURE.md          # This file
│   ├── MODULES.md               # Module reference
│   ├── MATERIALS.md             # Material system guide
│   ├── LIGHTING.md              # Lighting pipeline
│   ├── FEATURE-FLAGS.md         # Feature toggle reference
│   └── EXTENDING.md             # How to extend the template
│
├── modules/                     # GLSL module library
│   ├── anti-aliasing.glsl       # Anti-aliasing utilities
│   ├── background.glsl          # Procedural sky/background utilities
│   ├── camera.glsl              # Camera, DoF, shading entry point
│   ├── color.glsl               # Color manipulation utilities
│   ├── domain-repetition.glsl   # Space folding/repetition
│   ├── fog.glsl                 # Atmospheric fog
│   ├── hg_sdf.glsl              # Mercury's SDF library
│   ├── lighting.glsl            # All lighting calculations
│   ├── marching-engine.glsl     # Scene composition, raymarcher
│   ├── materials.glsl           # Material struct, presets
│   ├── modifiers.glsl           # SDF modifiers (twist, bend)
│   ├── noise.glsl               # Noise functions
│   ├── post.glsl                # Post-processing effects
│   ├── rotate.glsl              # Rotation matrices
│   └── sdf.glsl                 # Basic SDF primitives
│
└── programs/                    # Shader entry points
    ├── raymarching-template.fp.glsl  # Fragment shader (main)
    └── raymarching-template.vp.glsl  # Vertex shader
```

## Include Order

The JXS file defines the include order, which is critical for GLSL compilation. Dependencies must be included before dependents:

```
1. globals.glsl          # Constants, uniforms, feature flags
2. noise.glsl            # No dependencies
3. noise.glsl            # No dependencies
4. background.glsl       # Background helpers (depends on globals)
5. modifiers.glsl        # No dependencies
6. rotate.glsl           # No dependencies
7. hg_sdf.glsl           # SDF primitives library
8. sdf.glsl              # Custom SDF primitives
9. materials.glsl        # Material struct (depends on globals)
10. fog.glsl             # Fog utilities
11. domain-repetition.glsl # Domain operations
12. lighting.glsl        # Lighting (depends on materials, sdf)
13. color.glsl           # Color utilities
14. camera.glsl          # Camera, shading (depends on lighting)
15. post.glsl            # Post-processing
16. marching-engine.glsl # Scene, raymarcher (depends on all above)
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        Fragment Shader                          │
│                  (raymarching-template.fp.glsl)                 │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Camera Setup                               │
│              (camera.glsl: getCameraMatrix)                     │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Raymarching Loop                           │
│              (marching-engine.glsl: map)                        │
│                           │                                     │
│                           ▼                                     │
│              ┌─────────────────────────┐                        │
│              │    Scene Composition    │                        │
│              │   (getDist function)    │                        │
│              │   - SDF primitives      │                        │
│              │   - Material assignment │                        │
│              │   - Boolean operations  │                        │
│              └─────────────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Surface Shading                            │
│              (camera.glsl: shadeHit)                            │
│                           │                                     │
│           ┌───────────────┼───────────────┐                     │
│           ▼               ▼               ▼                     │
│     ┌──────────┐   ┌──────────┐   ┌──────────┐                  │
│     │ Lighting │   │Reflection│   │Refraction│                  │
│     │ getLight │   │getFirst- │   │  trace-  │                  │
│     │          │   │Reflection│   │Refraction│                  │
│     └──────────┘   └──────────┘   └──────────┘                  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Post-Processing                              │
│              (post.glsl: getPostProcessing)                     │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                          Final Color
```

## Key Abstractions

### SceneResult
Combines distance and material for scene composition:
```glsl
struct SceneResult {
    float dist;
    Material mat;
};
```

### Material
Full PBR+ material definition:
```glsl
struct Material {
    vec3 albedo;         // Base color
    float metallic;      // Metal vs dielectric
    float roughness;     // Surface roughness
    vec3 emission;       // Self-illumination
    float iridescence;   // Thin-film interference
    float subsurface;    // SSS amount
    vec3 subsurfaceCol;  // SSS color
    float transmission;  // Transparency
    float ior;           // Index of refraction
    float toonSteps;     // Toon shading bands
};
```

### Global State
The `gMaterial` global is set by `getDist()` and read by lighting functions. This enables material-aware lighting without passing materials through every function.

## Max/MSP Integration

The `.maxpat` file provides:
- `jit.gl.slab` object loading the `.jxs` shader
- Parameter controls for `lightPos`, `camPos`, `iTime`
- Render context management
- Real-time parameter tweaking

Uniforms are declared in `globals.glsl` and bound in the `.jxs` manifest.
