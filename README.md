# Helios

Claude usage dashboard for macOS and iOS. Visualizes Anthropic API usage as a living cosmic interface — orbital mechanics, waveforms, bioluminescent anemones, and fiber-textured irises.

## Platforms

### macOS — Multi-tab dashboard
Three visualization tabs: Orrery (solar system), Pulse (waveforms), Breakdown (eldritch anemone garden). Full admin overlay, settings with "Share to iOS" QR code.

### iOS — Cosmic anemone
Single-screen anemone organism with 3 tentacles (Hourly/5h cyan, Sonnet gold, Weekly/7d lavender). Features:
- **Fiber-based iris** at center — 80 radial muscle fibers, two-zone stroma (gold inner, teal outer), jagged collarette ring, crypts, dark limbal ring, irregular pupil border. Based on real iris anatomy.
- **Tentacles** adapted from Tempest — double-helix DNA strands, photophore nodes, 3-layer bulbous tips, membrane webbing, branching filaments. Length/wave driven by usage %.
- **Floating spores** background — 25 colored orbs drifting upward (replaced starfield for portrait).
- **Collar ring** and **ambient halo** with white→teal→gold color ramp (no red/orange).
- Tap tips or mid-nodes for tooltip. Readout bar at bottom with expandable detail view.

## Architecture

- **Rendering**: `TimelineView(.animation)` + `Canvas` (GraphicsContext) — deterministic animation from time, no mutable state
- **Data**: `UsageState` (@Observable) fed by `UsageEngine` polling Anthropic session cookies + admin API
- **macOS**: macOS 14+ (Sonoma), Swift 5.9, SwiftUI
- **iOS**: iOS 26+, built via GitHub Actions (Xcode 26), sideloaded via Sideloadly
- **Build (macOS)**: Xcode 16.2 (external drive)
- **Build (iOS)**: Push to `ios` branch → GitHub Actions → download IPA → Sideloadly

## Key Files

### macOS
| File | Purpose |
|------|---------|
| `OrreryView.swift` | Solar system tab — orbits, planets, nucleus |
| `PulseView.swift` | Waveform tab — waves, aurora, particles |
| `BreakdownView.swift` | Garden tab — plants, blooms, eyes, stalks, spores |
| `StarfieldCanvas.swift` | Reusable animated starfield background |
| `NucleusView.swift` | Pulsing center star with corona |
| `SettingsView.swift` | Settings + "Share to iOS" QR code |

### iOS (`HeliosIOS/`)
| File | Purpose |
|------|---------|
| `AnemoneView_iOS.swift` | Main anemone — iris, tentacles, spores, halo, collar, webbing |
| `ContentView_iOS.swift` | Root view with gear button + setup prompt |
| `SettingsView_iOS.swift` | QR scanner + session config |
| `StatsView_iOS.swift` | Detailed usage breakdown sheet |

### Shared (both targets)
| File | Purpose |
|------|---------|
| `Theme.swift` | Color palette — void, stardust, tier colors, tentacle gradients |
| `UsageState.swift` | Observable state: usage buckets, admin tokens, config |
| `UsageModels.swift` | Data models: UsageBucket, UsageResponse, tiers |
| `UsageEngine.swift` | Polling engine: session cookies + admin API |
| `Color+Ext.swift` | Color utilities (lerp, hex init, platform bridging) |

## Build & Deploy

### macOS
```bash
cd /Volumes/BASTIAN-4TB/Projects/Helios
xcodebuild -scheme Helios -configuration Release -derivedDataPath build clean build
pkill -x Helios; rm -rf /Applications/Helios.app && cp -R build/Build/Products/Release/Helios.app /Applications/ && open /Applications/Helios.app
```

### iOS
```bash
# 1. Push to ios branch (triggers GitHub Actions)
git push origin ios
# 2. Download IPA
gh run download --name HeliosIOS --dir ~/Downloads/HeliosIOS
# 3. Install via Sideloadly → iPhone (USB)
```

## Branches

- `main` — macOS stable (orrery + aurora + anemone/flower prototypes)
- `ios` — iOS anemone with fiber iris, floating spores, tentacles
