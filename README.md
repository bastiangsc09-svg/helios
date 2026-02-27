# Helios

Claude usage dashboard for macOS. Visualizes Anthropic API usage as a living cosmic interface — orbital mechanics, waveforms, and bioluminescent alien gardens.

## Tabs

### 1. Orrery (Solar System)
Usage buckets as orbiting planets around a pulsing nucleus. 3D gradient planets with specular highlights, atmosphere rim lights, conic gradient orbital rings, comet trails with ember sparks, expanding pulse rings. Usage-reactive orbital speed and glow.

### 2. Pulse (Waveforms)
Usage as layered animated waveforms. Aurora curtain fills, variable-thickness edges, baseline reflections, particle drift. Shimmer columns and idle aurora when no data.

### 3. Breakdown (Eldritch Garden)
Usage buckets as bioluminescent alien plants growing from a foggy ground line. Each plant has: tapered stalks with branching, tendrils with bioluminescent tips, glowing blooms with teardrop petals, eye orbs showing utilization %, spore particles, and underground mycelium connections. Hover interaction triggers tendril reaching, bloom brightening, mycelium pulsing, and spore scattering. Glassmorphic admin overlay at bottom.

**Flower design prototypes** (in progress): 3 candidate bloom designs in `FlowerTestView.swift`:
- **A — Anemone**: Sea-anemone with 14-18 undulating tentacle-petals and bioluminescent tips
- **B — Void Lotus**: 3-layer structured petals with veins, conic gradient ring, orbiting spores
- **C — Nebula Bloom**: Fibonacci spiral of translucent cloud-ellipses with filaments and sparkles

## Architecture

- **Rendering**: `TimelineView(.animation)` + `Canvas` (GraphicsContext) for all visual tabs — deterministic animation from time, no mutable state
- **Data**: `UsageState` (@Observable) fed by `UsageEngine` polling Anthropic session cookies + admin API
- **Platform**: macOS 14+ (Sonoma), Swift 5.9, SwiftUI
- **Build**: Xcode 16.2 (external drive)

## Key Files

| File | Purpose |
|------|---------|
| `OrreryView.swift` | Solar system tab — orbits, planets, nucleus |
| `PulseView.swift` | Waveform tab — waves, aurora, particles |
| `BreakdownView.swift` | Garden tab — plants, blooms, eyes, stalks, spores |
| `FlowerTestView.swift` | Flower design test harness (temporary) |
| `StarfieldCanvas.swift` | Reusable animated starfield background |
| `NucleusView.swift` | Pulsing center star with corona |
| `Theme.swift` | Color palette — void, stardust, tier colors, orbital identity |
| `UsageState.swift` | Observable state: usage buckets, admin tokens, config |
| `UsageModels.swift` | Data models: UsageBucket, UsageResponse, tiers |
| `UsageEngine.swift` | Polling engine: session cookies + admin API |
| `RESEARCH.md` | SwiftUI visual effects reference (Canvas, Metal, particles) |
| `TODO.md` | Next steps and feature backlog |

## Build & Deploy

```bash
cd /Volumes/BASTIAN-4TB/Projects/Helios
xcodebuild -scheme Helios -configuration Release -derivedDataPath build clean build
pkill -x Helios; rm -rf /Applications/Helios.app && cp -R build/Build/Products/Release/Helios.app /Applications/ && open /Applications/Helios.app
```

## Branches

- `main` — stable, all 3 flower prototypes + full garden implementation
- `flower-anemone` — Anemone bloom integration into garden
- `flower-lotus` — Void Lotus bloom integration into garden
