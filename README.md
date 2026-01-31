# Raymarching Template

A modular raymarching shader template for Max/MSP Jitter with PBR materials, advanced lighting, and extensible architecture.

## Features

- **PBR Material System** - Metallic/roughness workflow with full material control
- **Advanced Materials** - SSS, iridescence, transparency/refraction, toon shading
- **Flexible Lighting** - Directional, point, and spot lights with colored caustic shadows and optional GI
- **Modular Architecture** - Feature flags for enabling/disabling techniques
- **Depth of Field** - Polygon-shaped bokeh with temporal jitter
- **Extensible** - Clean separation of concerns for easy customization

## Quick Start

1. Open `raymarching-template.maxpat` in Max/MSP
2. Enable the render context
3. Adjust `lightPos` and `camPos` to explore the scene
4. Modify `iTime` or connect to a timing source for animation

## Project Structure

```
raymarching-template/
├── globals.glsl              # Feature flags and uniforms
├── raymarching-template.jxs  # Shader manifest
├── raymarching-template.maxpat
├── modules/                  # GLSL module library
│   ├── materials.glsl        # Material system
│   ├── lighting.glsl         # Lighting calculations
│   ├── camera.glsl           # Camera and shading
│   ├── marching-engine.glsl  # Scene composition
│   └── ...
├── programs/                 # Shader entry points
│   └── raymarching-template.fp.glsl
└── docs/                     # Documentation
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | Project structure and data flow |
| [Materials](docs/MATERIALS.md) | Material system and presets |
| [Lighting](docs/LIGHTING.md) | Lighting pipeline and shadows |
| [Feature Flags](docs/FEATURE-FLAGS.md) | Performance toggles |
| [Extending](docs/EXTENDING.md) | How to add features |
| [Modules](docs/MODULES.md) | Module API reference |

## Feature Flags

Toggle rendering techniques in `globals.glsl`:

```glsl
#define RM_ENABLE_IRIDESCENCE 1      // Thin-film interference
#define RM_ENABLE_SSS 1              // Subsurface scattering
#define RM_ENABLE_EMISSIVE 1         // Emissive lights
#define RM_ENABLE_TOON 1             // Cel shading
#define RM_ENABLE_REFRACTION 1       // Glass/water transparency
#define RM_ENABLE_REFLECTIONS 1      // Surface reflections
#define RM_ENABLE_SPOTLIGHT 1        // Spot/point lights
#define RM_ENABLE_AMBIENT_OCCLUSION 1
#define RM_ENABLE_CAUSTIC_SHADOWS 1  // Colored shadows (expensive)
#define RM_ENABLE_ENV_MAP 0          // Environment map for reflections
#define RM_ENABLE_GI 0               // Cheap hemispherical GI
```

Set to `0` to disable features for performance.

## Adding Objects

Edit `getDist()` in `modules/marching-engine.glsl`:

```glsl
// Add a red plastic sphere
vec3 myPos = pos - vec3(0.0, 0.3, 0.5);
SceneResult mySphere = sceneResult(
    fSphere(myPos, 0.15),
    matPlastic(vec3(1.0, 0.2, 0.2))
);
scene = sceneMin(scene, mySphere);
```

## Material Presets

```glsl
matPlastic(color)     // Shiny plastic
matMetal(color)       // Polished metal
matRubber(color)      // Matte rubber
matGold()             // Polished gold
matMirror()           // Perfect mirror
matGlass()            // Amber glass
matWater()            // Ocean water
matWax(color)         // Candle wax (SSS)
matSkin(color)        // Human skin (SSS)
matSoapBubble()       // Iridescent bubble
matToon(color, steps) // Cel shaded
```

See [Materials Documentation](docs/MATERIALS.md) for full list.

## Performance Tips

1. **Disable caustic shadows** - Set `RM_ENABLE_CAUSTIC_SHADOWS 0`
2. **Reduce MAX_STEPS** - Lower from 500 to 200-300
3. **Disable unused features** - Turn off SSS, refraction if not used
4. **Simplify scene** - Fewer objects = faster rendering

## Requirements

- Max/MSP 8+ with Jitter
- OpenGL 3.3+ compatible GPU
- For full features: Modern discrete GPU recommended

## Acknowledgments

- Mercury's hg_sdf library for SDF primitives
- Inigo Quilez for raymarching techniques
