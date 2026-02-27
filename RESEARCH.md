# Helios — Visual Effects Research Reference

Compiled from 4 research agents. Target: macOS 14 (Sonoma), Swift 5.9, Xcode 16.

---

## 1. Canvas Advanced Rendering (GraphicsContext)

### Gradients Available in Canvas
- **Radial** — `.radialGradient(...)` — planet surfaces, glow halos
- **Linear** — `.linearGradient(...)` — atmospheric bands (Jupiter-like)
- **Conic/Angular** — `.conicGradient(...)` — rings, vortices, non-uniform brightness

### Blending Modes (set on context or drawLayer)
| Mode | Use For |
|------|---------|
| `.screen` | Glow halos, atmospheric scatter |
| `.additive` / `.plusLighter` | Energy effects, stars, plasma |
| `.overlay` | Surface texture detail |
| `.multiply` | Shadow overlay, darkside shading |
| `.colorDodge` | Solar corona, lens flare |
| `.softLight` | Atmospheric haze |

### Filters (`ctx.addFilter()`)
- `.blur(radius:)` — Gaussian blur
- `.shadow(color:radius:x:y:)` — drop shadow
- `.colorMultiply(Color)` — tinting
- `.saturation(Double)` — 0=grayscale, 1=normal, >1=over
- `.brightness(Double)`, `.contrast(Double)`, `.hueRotation(Angle)`
- `.luminanceToAlpha` — brightness to opacity
- `.alphaThreshold(minimum:color:)` — macOS 14+

**Important:** Filters are cumulative. Use `drawLayer {}` to isolate.

### Multi-Pass Planet Rendering (6 passes)
1. **Deep background glow** — blurred radial gradient, `.normal` blend
2. **Base sphere** — radial gradient offset toward light source for 3D illusion
3. **Surface texture** — clipped horizontal streaks, `.overlay` blend, low opacity
4. **Atmosphere rim light** — arc stroke on sunlit side, `.screen` blend, blurred
5. **Specular highlight** — small bright ellipse offset to light, `.additive` blend
6. **Outer corona** — blurred ring stroke, `.additive` blend

### Resolved Images in Canvas
```swift
if let texture = ctx.resolve(Image("planet_texture")) {
    ctx.drawLayer { texCtx in
        texCtx.blendMode = .overlay
        texCtx.opacity = 0.4
        texCtx.clip(to: planetPath)
        texCtx.draw(texture, in: planetRect)
    }
}
```
Can composite pre-rendered textures (from Nano Banana or CIFilter noise) into Canvas.

### Procedural Textures in Canvas
No built-in noise functions. Three strategies:
- **A) Fake it** — hundreds of overlapping semi-transparent ellipses with `.screen` blend
- **B) Pre-render** — generate textures offline with CIFilter/Metal, bundle as assets
- **C) CIFilter at runtime** — `CIFilter.randomGenerator()` → `CIFilter.colorControls()` → CGImage → resolved Image

---

## 2. Metal Shaders in SwiftUI (macOS 14+)

### Three Shader Modifiers
- **`.colorEffect()`** — per-pixel color transform. Params: `(float2 position, half4 color, ...)`
- **`.distortionEffect()`** — geometry warp. Params: `(float2 position, ...)`  returns new `float2`
- **`.layerEffect()`** — full layer sampling. Params: `(float2 position, SwiftUI::Layer layer, ...)`

### Writing .metal Files
1. Add a `.metal` file to the Xcode project
2. Mark functions with `[[ stitchable ]]`
3. `#include <SwiftUI/SwiftUI_Metal.h>` for layerEffect
4. Reference via `ShaderLibrary.functionName(.float(value), .float2(size), .color(c))`

### Key Shader Examples

**Wave distortion:**
```metal
[[ stitchable ]] float2 wave(float2 position, float time) {
    return position + float2(sin(time + position.y / 20), sin(time + position.x / 20)) * 5;
}
```

**Noise/shimmer:**
```metal
[[ stitchable ]] half4 noise(float2 position, half4 currentColor, float time) {
    float value = fract(sin(dot(position + time, float2(12.9898, 78.233))) * 43758.5453);
    return half4(value, value, value, 1) * currentColor.a;
}
```

**Pixellate (layer sampling):**
```metal
[[ stitchable ]] half4 pixellate(float2 position, SwiftUI::Layer layer, float strength) {
    float min_strength = max(strength, 0.0001);
    float coord_x = min_strength * round(position.x / min_strength);
    float coord_y = min_strength * round(position.y / min_strength);
    return layer.sample(float2(coord_x, coord_y));
}
```

### Inferno Library (twostraws/Inferno)
Open-source collection of ready-made Metal shaders for SwiftUI. Includes:
fire, water, plasma, electric spark, emboss, infrared, light grid, and more.
Can be added as a Swift Package dependency.

### Performance
- Fully GPU-accelerated, runs at 60fps on integrated graphics
- Use `TimelineView(.animation)` to pass time uniform
- `.visualEffect { content, proxy in }` to pass view size to shader
- Pre-compile with `try await shader.compile(as: .colorEffect)` on iOS 18+ / macOS 15+

---

## 3. Particle Systems

### TimelineView + Canvas (Pure SwiftUI)
- 500-1000 particles at 60fps on Apple Silicon
- Use `struct` particles (value types, cache-friendly)
- Pre-allocate arrays, cap particle count (~600 max)
- `.drawingGroup()` flattens to single Metal layer

### Architecture Pattern
```swift
@Observable class ParticleSystem {
    var particles: [Particle] = []
    func emit(at:) { /* spawn particles */ }
    func update(at date: Date) { /* physics step, cull dead */ }
}

TimelineView(.animation) { timeline in
    Canvas { ctx, size in
        system.update(at: timeline.date)
        for p in system.particles { /* draw */ }
    }
}
```

### CAEmitterLayer (via NSViewRepresentable)
- GPU-accelerated, handles 5,000+ particles trivially
- Built-in physics: velocity, acceleration, spin, birth/death rates
- `.renderMode = .additive` for glow/bloom
- Less flexible than Canvas but massively more performant

### SpriteKit (via SpriteView)
- `SpriteView(scene:options:[.allowsTransparency])` layers behind SwiftUI
- `SKEmitterNode` for particle effects
- Best for persistent background effects (nebula, star field)
- Xcode has a visual particle editor (.sks files)

### PhaseAnimator (macOS 14+)
- Cycles through discrete states with auto-interpolation
- Good for: pulsing stars, breathing rings, status indicators
- NOT for mass particles (one state machine per instance)
```swift
PhaseAnimator(PulsePhase.allCases) { phase in
    Circle()
        .scaleEffect(phase.scale)
        .opacity(phase.opacity)
        .blur(radius: phase.blur)
} animation: { phase in
    switch phase { /* different timing per phase */ }
}
```

### KeyframeAnimator (macOS 14+)
- Independent keyframe tracks per property
- Precise timing control (linear, spring, cubic per track)
- Best for choreographed orbital motions
```swift
KeyframeAnimator(initialValue: Values(), repeating: true) { values in
    /* render with values.scale, values.rotation, etc */
} keyframes: { _ in
    KeyframeTrack(\.offsetX) { CubicKeyframe(150, duration: 1.0) /* ... */ }
    KeyframeTrack(\.glowIntensity) { SpringKeyframe(1.0, duration: 1.0, spring: .bouncy) }
}
```

---

## 4. Nano Banana 2 (Image Generation)

### Model & API
- **Friendly name:** Nano Banana 2
- **Model ID:** `gemini-3.1-flash-image-preview`
- **Provider:** LaoZhang.ai (Gemini-native endpoint)
- **Cost:** $0.05/image (any resolution)
- **Default:** 4K, 16:9

### Script Location
`/Users/bastianc/openclaw-collective/base/skills/nano-banana/scripts/nano_banana.py`

### Usage for Helios Assets
```bash
# Planet surface texture (square for mapping)
python3 nano_banana.py "Highly detailed alien planet surface texture, volcanic terrain with glowing magma veins, top-down view, seamless texture, 8K quality" --aspect "1:1" --resolution "4K"

# Nebula background
python3 nano_banana.py "Deep space nebula, swirling cosmic gas in purple cyan magenta, Hubble style, 8K quality" --aspect "16:9" --resolution "4K"

# Batch variations
python3 nano_banana.py "Gas giant atmospheric bands, Jupiter-like storms" --aspect "1:1" --resolution "4K" --batch 4
```

### Output
- Format: PNG, 1-11 MB
- Directory: `~/sharedworkflow/Projects/NanoBanana/outputs/`
- Filename: `generated_YYYYMMDD_HHMMSS.png`

---

## 5. API Availability Summary (macOS 14)

| Feature | Available | Notes |
|---------|-----------|-------|
| TimelineView + Canvas | Yes (13+) | Animation workhorse |
| GraphicsContext blending/filters | Yes (13+) | Full CGBlendMode set |
| PhaseAnimator | Yes (14+) | Discrete state cycling |
| KeyframeAnimator | Yes (14+) | Multi-track keyframes |
| `.visualEffect {}` | Yes (14+) | Position-reactive transforms |
| Metal shaders (.colorEffect etc) | Yes (14+) | GPU pixel shaders |
| Spring struct (.smooth/.bouncy) | Yes (14+) | Physics-based springs |
| `.drawingGroup()` | Yes (13+) | Flatten to Metal texture |
| CAEmitterLayer | Yes (10.6+) | Via NSViewRepresentable |
| SpriteView | Yes (12+) | SpriteKit in SwiftUI |
| `@Observable` | Yes (14+) | Modern observation |
| MeshGradient | **NO** (15+ only) | Not on Sonoma |

---

## 6. Recommended Architecture for Helios

1. **Background** — SpriteKit `SKScene` via `SpriteView` for nebula/aurora/starfield (thousands of persistent particles, zero Swift per-frame cost)
2. **Mid layer** — `TimelineView` + `Canvas` for orbital mechanics, planet rendering (multi-pass: base gradient → texture → rim light → specular → corona), dust cloud, spark trails
3. **Foreground** — Standard SwiftUI views + PhaseAnimator for UI elements (readout capsule, pulsing indicators)
4. **Metal shaders** — `.colorEffect()` for shimmer on text/UI, `.distortionEffect()` for heat wave near nucleus
5. **Generated assets** — Nano Banana 2 for static textures (planet surfaces, nebula tiles) composited via resolved images in Canvas
6. **Performance** — `.drawingGroup()` on Canvas layers, `.blendMode(.plusLighter)` on particle layers for additive glow
