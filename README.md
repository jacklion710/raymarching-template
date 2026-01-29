# Raymarching Template - Max MSP Jitter

Launch point for new shader compositions. The goal is to provide the boilerplate and raymarching engine as well as any additional tools for enhancing the scene

## Overview

NOTE: Later it may be nice to add controls to enable/disable different lighting properties in getLight()

TODO:
- Implement new materials
    - Subsurface Scattering - Light penetrating translucent surfaces (skin, wax, leaves)
    - Transparency/Refraction - Glass, water, crystals (requires ray bending)
    - Iridescence - Color shifts based on view angle (soap bubbles, oil slicks, beetle shells)
    - Toon/Cel Shading - Stylized stepped lighting for cartoon look
- Support multiple emissive objects
- Anti aliasing
- Palette function and lighting for hetti styles
- Glean/glimmer for metallic materials