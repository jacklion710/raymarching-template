# Raymarching Template - Max MSP Jitter

Launch point for new shader compositions. The goal is to provide the boilerplate and raymarching engine as well as any additional tools for enhancing the scene

## Overview

NOTE: Later it may be nice to add controls to enable/disable different lighting properties in getLight()

TODO:
- Implement new materials
    - Transparency/Refraction - Glass, water, crystals with refraction toggle (RM_ENABLE_REFRACTION)
    - Toon/Cel Shading - Stylized stepped lighting with band controls (RM_ENABLE_TOON)
- Material enhancements
    - Should SSS really emit as much light as it currently does or should it absorb most of it instead?
    - Explore iridescence enhancements if any
- Anti aliasing
- Denoising
- Glean/glimmer for metallic materials
- stagger control for flickering so they're not all in sync
- SSS light absotption fix
- Cool hg modifiers
- Palette function and lighting for hetti styles