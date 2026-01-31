# Feature Flags

Feature flags allow you to enable/disable rendering techniques at compile time. This is useful for:
- **Performance tuning** - Disable expensive features on weaker GPUs
- **Debugging** - Isolate specific effects
- **Customization** - Build stripped-down versions for specific use cases

## Configuration

All flags are defined in `globals.glsl`:

```glsl
// Set to 0 to disable, 1 to enable
#define RM_ENABLE_IRIDESCENCE 1
#define RM_ENABLE_SSS 1
#define RM_ENABLE_EMISSIVE 1
#define RM_ENABLE_TOON 1
#define RM_ENABLE_REFRACTION 1
#define RM_ENABLE_REFLECTIONS 1
#define RM_ENABLE_SPOTLIGHT 1
#define RM_ENABLE_AMBIENT_OCCLUSION 1
#define RM_ENABLE_CAUSTIC_SHADOWS 1
#define RM_ENABLE_ENV_MAP 0
#define RM_ENABLE_GI 0
```

## Flag Reference

### RM_ENABLE_IRIDESCENCE

**Controls:** Thin-film interference color shifting

**Affects:**
- `getIridescentColor()` in materials.glsl
- View-dependent color calculation in lighting.glsl
- Enhanced Fresnel in camera.glsl

**Performance cost:** Low (simple color math per pixel)

**When to disable:** When not using iridescent materials

---

### RM_ENABLE_SSS

**Controls:** Subsurface scattering simulation

**Affects:**
- SSS sphere showcase in marching-engine.glsl
- Thickness sampling in lighting.glsl
- Absorption and color bleeding calculations
- Colored shadow bleeding

**Performance cost:** Medium-High (4+ extra SDF samples per lit pixel)

**When to disable:** When not using SSS materials (wax, skin, jade, marble)

---

### RM_ENABLE_EMISSIVE

**Controls:** Emissive light sources and glow

**Affects:**
- Emissive sphere geometry in marching-engine.glsl
- Area light calculations in lighting.glsl
- Shadow behavior (emissives don't block light)

**Performance cost:** Medium (loop over emissive sources)

**When to disable:** When using only external lighting

---

### RM_ENABLE_TOON

**Controls:** Cel-shaded/cartoon rendering

**Affects:**
- Stepped diffuse and specular in lighting.glsl
- Hard shadow edges
- AO skipping for clean look

**Performance cost:** Low (actually cheaper than PBR - fewer calculations)

**When to disable:** When not using toon materials

---

### RM_ENABLE_REFRACTION

**Controls:** Transparent material refraction

**Affects:**
- Glass/water/crystal showcase in marching-engine.glsl
- `traceRefraction()` in camera.glsl
- Entry/exit refraction calculation
- Beer-Lambert absorption

**Performance cost:** High (64+ steps to trace through object)

**When to disable:** When not using transparent materials

---

### RM_ENABLE_REFLECTIONS

**Controls:** Surface reflections

**Affects:**
- `getFirstReflection()` calls in camera.glsl
- Fresnel-based reflection blending

**Performance cost:** Medium (secondary ray per reflective pixel)

**When to disable:** For matte-only scenes or maximum performance

---

### RM_ENABLE_SPOTLIGHT

**Controls:** Spotlight and point light sources

**Affects:**
- Spotlight calculations in lighting.glsl
- Additional point lights for caustic shadows
- Backlighting for SSS row

**Performance cost:** Medium (extra shadow rays per light)

**When to disable:** When using only the main directional light

---

### RM_ENABLE_AMBIENT_OCCLUSION

**Controls:** Screen-space ambient occlusion

**Affects:**
- `getAmbientOcclusion()` in lighting.glsl
- Contact shadow darkening

**Performance cost:** Medium (5 SDF samples per pixel)

**When to disable:** For flat-lit or stylized looks

---

### RM_ENABLE_CAUSTIC_SHADOWS

**Controls:** Colored caustic shadows

**Affects:**
- `getColoredShadow()` vs `getSimpleShadow()` in lighting.glsl
- SSS color bleeding into shadows
- Transparent material light tinting
- Iridescent rainbow shadows

**Performance cost:** High (extra material lookups and calculations per shadow ray)

**When to disable:** On weaker GPUs or when colored shadows aren't needed

---

### RM_ENABLE_ENV_MAP

**Controls:** Directional environment background for reflections

**Affects:**
- Reflection fallback in `getFirstReflection()` (lighting.glsl)
- Uses scene background as a sky/environment map

**Performance cost:** Low

**When to disable:** If you want flat background reflections (faster but less accurate)

---

### RM_ENABLE_GI

**Controls:** Cheap hemispherical global illumination bounce

**Affects:**
- `getGlobalIllumination()` in lighting.glsl
- Ambient balance in `getLight()` (ambient is reduced when GI is enabled)

**Performance cost:** Low (simple per-pixel math)

**When to disable:** For flat lighting or maximum performance

## Performance Presets

### Maximum Quality
```glsl
#define RM_ENABLE_IRIDESCENCE 1
#define RM_ENABLE_SSS 1
#define RM_ENABLE_EMISSIVE 1
#define RM_ENABLE_TOON 1
#define RM_ENABLE_REFRACTION 1
#define RM_ENABLE_REFLECTIONS 1
#define RM_ENABLE_SPOTLIGHT 1
#define RM_ENABLE_AMBIENT_OCCLUSION 1
#define RM_ENABLE_CAUSTIC_SHADOWS 1
#define RM_ENABLE_ENV_MAP 0
#define RM_ENABLE_GI 0
```

### Balanced (Recommended)
```glsl
#define RM_ENABLE_IRIDESCENCE 1
#define RM_ENABLE_SSS 1
#define RM_ENABLE_EMISSIVE 1
#define RM_ENABLE_TOON 1
#define RM_ENABLE_REFRACTION 1
#define RM_ENABLE_REFLECTIONS 1
#define RM_ENABLE_SPOTLIGHT 1
#define RM_ENABLE_AMBIENT_OCCLUSION 1
#define RM_ENABLE_CAUSTIC_SHADOWS 0  // Disable expensive caustics
#define RM_ENABLE_ENV_MAP 0
#define RM_ENABLE_GI 0
```

### Performance Mode
```glsl
#define RM_ENABLE_IRIDESCENCE 1
#define RM_ENABLE_SSS 0              // Disable SSS
#define RM_ENABLE_EMISSIVE 1
#define RM_ENABLE_TOON 1
#define RM_ENABLE_REFRACTION 0       // Disable refraction
#define RM_ENABLE_REFLECTIONS 1
#define RM_ENABLE_SPOTLIGHT 0        // Single light only
#define RM_ENABLE_AMBIENT_OCCLUSION 0
#define RM_ENABLE_CAUSTIC_SHADOWS 0
#define RM_ENABLE_ENV_MAP 0
#define RM_ENABLE_GI 0
```

### Minimal (Maximum Performance)
```glsl
#define RM_ENABLE_IRIDESCENCE 0
#define RM_ENABLE_SSS 0
#define RM_ENABLE_EMISSIVE 0
#define RM_ENABLE_TOON 0
#define RM_ENABLE_REFRACTION 0
#define RM_ENABLE_REFLECTIONS 0
#define RM_ENABLE_SPOTLIGHT 0
#define RM_ENABLE_AMBIENT_OCCLUSION 0
#define RM_ENABLE_CAUSTIC_SHADOWS 0
#define RM_ENABLE_ENV_MAP 0
#define RM_ENABLE_GI 0
```

## Raymarch Settings

In addition to feature flags, `globals.glsl` contains raymarch parameters:

```glsl
#define MAX_STEPS 500    // Maximum raymarch iterations
#define MIN_DIST 0.0001  // Surface hit threshold
```

**Tuning tips:**
- Lower `MAX_STEPS` (200-300) for better performance
- Increase `MIN_DIST` (0.001) for faster but less precise hits
- For distant views, both can be relaxed significantly

## Complexity Analysis

Understanding which flags impact performance helps prioritize:

| Flag | Per-Pixel Cost | Shadow Cost | Notes |
|------|---------------|-------------|-------|
| IRIDESCENCE | Low | None | Simple color math |
| SSS | High | High | Multiple SDF samples |
| EMISSIVE | Medium | Low | Loop over light sources |
| TOON | Low | None | Simpler than PBR |
| REFRACTION | Very High | Medium | Full ray trace through object |
| REFLECTIONS | Medium | None | Secondary ray |
| SPOTLIGHT | Medium | Medium | Extra shadow rays |
| AMBIENT_OCCLUSION | Medium | None | 5 SDF samples |
| CAUSTIC_SHADOWS | High | Very High | Material-aware shadow tracing |

**Total scene cost** = Base raymarch + Sum of enabled feature costs
