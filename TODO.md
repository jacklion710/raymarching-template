# TODO

## High Priority

### Materials & Effects
- [ ] Anti-aliasing implementation
- [ ] Denoising pass
- [ ] Glean/glimmer effect for metallic materials
- [ ] Environment map background
- [ ] Interesting procedural background

### SSS Improvements
- [ ] Review SSS light absorption vs emission balance
- [ ] Stagger control for emissive flickering (currently all in sync)

### Iridescence
- [ ] Explore additional iridescence enhancements

## Medium Priority

### Visual Polish
- [ ] Palette function for stylized color schemes
- [ ] "Hetti style" lighting presets
- [ ] Cool hg_sdf modifier showcases

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
