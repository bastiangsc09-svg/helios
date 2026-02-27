# Helios — Next Steps

## Planet Texture Integration (Ready to implement)

Three 4K planet textures were generated with Nano Banana 2 (gemini-3.1-flash-image-preview via LaoZhang):

| Orbit | Texture File | Size |
|-------|-------------|------|
| Session (cyan) | `~/SharedWorkflow/Projects/NanoBanana/outputs/generated_20260227_060421.png` | 23.8 MB |
| Outer (gold) | `~/SharedWorkflow/Projects/NanoBanana/outputs/generated_20260227_060548.png` | 22.3 MB |
| Weekly (purple) | `~/SharedWorkflow/Projects/NanoBanana/outputs/generated_20260227_060553.png` | 23.0 MB |

### How to apply them to the planets

The planets are drawn in `OrreryView.swift` inside `drawOrbits()` using Canvas `GraphicsContext`.

**Steps:**
1. **Resize textures** — Planets are 6-12px radius on screen. Downscale the 4K PNGs to ~128x128 or 256x256 and add to the Xcode project's asset catalog (`Helios/Assets.xcassets/`) as `planet_session`, `planet_weekly`, `planet_outer`
2. **Resolve in Canvas** — At the top of `drawOrbits`, resolve the images:
   ```swift
   let sessionTex = ctx.resolve(Image("planet_session"))
   let weeklyTex = ctx.resolve(Image("planet_weekly"))
   let outerTex = ctx.resolve(Image("planet_outer"))
   ```
3. **Composite with drawLayer** — After the 3D gradient base, overlay the texture clipped to the planet circle:
   ```swift
   ctx.drawLayer { texCtx in
       texCtx.clip(to: Circle().path(in: CGRect(x: px - ps, y: py - ps, width: ps * 2, height: ps * 2)))
       texCtx.blendMode = .overlay
       texCtx.opacity = 0.4
       texCtx.draw(resolvedTexture, in: CGRect(x: px - ps, y: py - ps, width: ps * 2, height: ps * 2))
   }
   ```
4. **Map textures to orbits** — Add a texture field to the orbits tuple, or use index to pick the right resolved image
5. Keep specular highlight and rim light AFTER the texture overlay so they render on top

### Performance note
- Resolve images once per frame (they're valid for the current frame only)
- `drawLayer` creates an offscreen buffer — 3 extra per frame is fine at 60fps
- 256x256 textures are plenty for the small planet sizes

## Other Features from Research (RESEARCH.md)

### High priority
- **Metal distortion shader** — Gravitational lensing around the nucleus (space-warping effect). Requires creating a `.metal` file, adding to pbxproj, and applying `.distortionEffect()` to the starfield
- **Reactive dust cloud** — 200-300 floating particles with inverse-square repulsion from passing planets + spring back to rest position. Needs `@Observable` particle system class
- **CAEmitterLayer nucleus embers** — GPU-accelerated particle stream drifting upward from nucleus. Requires `NSViewRepresentable` bridge

### Medium priority
- **Chromatic aberration shader** — Split RGB at edges for sci-fi lens effect
- **Energy shimmer on readout capsule** — Animated noise `.colorEffect()`
- **KeyframeAnimator nucleus heartbeat** — Choreographed multi-property animation

### Lower priority / polish
- **SpriteKit background** — Replace StarfieldCanvas with SKScene for heavier particle work
- **CIFilter noise textures** — Runtime Perlin noise on planet surfaces (alternative to Nano Banana)

## Current State (2026-02-27)

### Orrery Tab
- 3D gradient planets with specular highlights
- Atmosphere rim lights on sunlit edge
- Conic gradient orbital rings (directional light)
- Enhanced comet trails (tapering width, quadratic fade)
- Ember spark particles scattered along trails
- Nebula color wash background (purple, teal, magenta blobs)
- Diffraction spikes on brightest stars
- Expanding pulse rings from nucleus
- Usage-reactive orbital speed + glow (exponential curve)
- Clickable capsule/table toggle with spring animation
- Glowing white labels, tier-colored percentages, reset timers

### Pulse Tab
- Aurora cosmic waveform rendering
- Compact glass chip stats
- Variable-thickness edges, shimmer columns, idle aurora

### Breakdown Tab (Eldritch Garden) — NEW
- Full garden rewrite: plants grow from foggy ground line
- Per-plant: tapered stalks with branches, tendrils, blooms, eye orbs, labels
- Ground fog (3 drifting gradient bands), mycelium network with pulse animation
- 40 spore particles (color-matched, hover-repelled)
- Hover interaction: bloom brightening, tendril reaching, spore scatter
- Glassmorphic admin overlay (.ultraThinMaterial)
- **Flower design selection in progress** — 3 prototypes in FlowerTestView:
  - A: Anemone (tentacle-petals) — `flower-anemone` branch
  - B: Void Lotus (layered petals + veins) — `flower-lotus` branch
  - C: Nebula Bloom (fibonacci cloud-ellipses) — available in FlowerRenderer
