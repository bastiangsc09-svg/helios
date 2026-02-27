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

### Breakdown Tab (Eldritch Anemones) — Active on `flower-anemone`
- 3 big anemones on starfield + ground fog (no stalks/garden)
- `FlowerRenderer` in `FlowerTestView.swift` has 3 anemone variants + shared eye:
  - `drawDeepSea` (Session/cyan) — 14-18 thin fast tentacles, small tip dots
  - `drawCrown` (Weekly/lavender) — 8-10 thick tentacles, large bulbous tips, collar ring
  - `drawSpiral` (Sonnet/gold) — 12 corkscrewing tentacles, trailing wisps, slow rotation
- All take `brightness` param for hover (1.0 normal, 1.5 hovered)
- Labels: short label + percentage + reset timer below each flower
- Buckets limited to `allBuckets.prefix(3)` for consistency with OrreryView/PulseView
- Old garden code (stalks, tendrils, mycelium, spores) still in file but not called
- `FlowerTestView` has slider test harness showing all 3 variants
- Glassmorphic admin overlay (.ultraThinMaterial)

### Known Bugs (fixed)
- ~~Labels only showed for Crown (center)~~ — Fixed: split into 2-pass rendering (flowers first, labels second)
- ~~Percentage text in eye orbs looked bad~~ — Fixed: moved % below the short label instead of inside the flower

### Branches
- `main` — safe checkpoint with all 3 original flower prototypes (Anemone/Lotus/Nebula) + docs
- `flower-anemone` — 3 anemone variants integrated, big flowers layout (active)
- `flower-lotus` — parked for Void Lotus alternative
