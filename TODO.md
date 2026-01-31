# TODO

## High Priority

### Materials & Effects
- [ ] Anti-aliasing implementation
- [ ] Denoising pass
- [ ] Multipass (Max/Jitter slab chain): render raymarch pass to texture (pack depth/aux), then post passes for bloom + FXAA + SSS + optional temporal accumulation; [watch this](https://www.youtube.com/watch?v=9O80hGMtW6Q)
- [ ] Glean/glimmer effect 
- [ ] Stagger control for emissive flickering (currently all are in sync) [check the showcase scene for flicker visibility]
- [ ] See if you can create a reference and click to go to a section of markdown from code

### Iridescence
- [ ] Explore additional iridescence enhancements

### Global Illumination
- [ ] Ensure each material adheres to their unique rules for GI

## Medium Priority

### Visual Polish
- [ ] Palette function for stylized color schemes
- [ ] "Hetti style" lighting presets
- [ ] Cool hg_sdf modifier showcases
- [ ] Flickering point and cone lights.

### Performance
- [ ] Profile caustic shadows on various GPUs
- [ ] Optimize SSS thickness sampling
- [ ] Add LOD system for distant objects

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