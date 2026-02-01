# TODO

## High Priority

### Materials & Effects
- [ ] Anti-aliasing implementation
- [ ] Denoising pass
- [ ] Multipass (Max/Jitter slab chain): render raymarch pass to texture (pack depth/aux), then post passes for bloom + FXAA + SSS + optional temporal accumulation; [watch this](https://www.youtube.com/watch?v=9O80hGMtW6Q)
- [ ] Glean/glimmer effect 
- [ ] See if you can create a reference and click to go to a section of markdown from code

## Medium Priority

### Performance
- [ ] Profile caustic shadows on various GPUs
- [ ] Optimize SSS thickness sampling
- [ ] Adaptive step count by distance (LOD bands)
- [ ] Feature gating by distance (refraction/SSS/iridescence/caustics)
- [x] Reduce AO/shadow sample counts for far hits
- [ ] Shadow LOD: switch to simple shadows at distance
- [ ] Material simplification for far objects
- [ ] Early-out for rays unlikely to hit (sky/background)
- [ ] Scene-level culling with cheap bounding volumes

## Low Priority / Future Ideas

### New Material Types
- [ ] Velvet/cloth materials
- [ ] Anisotropic metals (brushed metal)
- [ ] Volumetric materials (smoke, fog volumes)

### Scene Management
- [ ] Scene switching system
- [ ] Camera animation presets
- [ ] Light animation presets

## Completed

- [x] Transparency/Refraction - Glass, water, crystals (RM_ENABLE_REFRACTION)
- [x] Toon/Cel Shading - Stylized stepped lighting (RM_ENABLE_TOON)
- [x] SSS light absorption fix with Beer-Lambert law
- [x] Caustic colored shadows for transparent materials
- [x] Feature flag system for toggling techniques
- [x] Global illumination toggle (RM_ENABLE_GI)
for metallic materials
- [x] Interesting procedural background
- [x] Environment map background
- [x] Cool hg_sdf modifier showcases
- [x] Ensure each material adheres to their unique rules for GI
- [x] Explore additional iridescence enhancements and create a showcase scene
- [x] Stagger control for emissive flickering (currently all are in sync) [check the showcase scene for flicker visibility]
- [x] Flickering point and cone lights
- [x] Night lights showcase scene with moon
- [x] Palette function for stylized color schemes
- [x] Add LOD system for distant objects
