# Helios — Project Instructions

## Build & Deploy
```bash
cd /Volumes/BASTIAN-4TB/Projects/Helios
xcodebuild -scheme Helios -configuration Release -derivedDataPath build clean build
pkill -x Helios; rm -rf /Applications/Helios.app && cp -R build/Build/Products/Release/Helios.app /Applications/ && open /Applications/Helios.app
```

## Architecture
- All visual tabs use **TimelineView(.animation) + Canvas** pattern
- Animation is deterministic from `time` (Double, seconds since reference) — no mutable animation state
- Drawing functions: `private func draw...(ctx: inout GraphicsContext, ...)`
- Colors from `Theme.*` constants, tier colors via `Color.forUtilization(pct)`
- Blend modes: `.screen` and `.plusLighter` for glow, `.overlay` for textures
- `@State` only for hover position and UI toggles
- Existing tabs: OrreryView (solar system), PulseView (waveforms), BreakdownView (garden)

## Data Model
- `UsageState` is `@Observable`, passed as `let state: UsageState` to all views
- `state.usage?.allBuckets` → up to 6 `(label, shortLabel, bucket: UsageBucket)` tuples
- `UsageBucket.utilization` (0-100), `UsageBucket.resetsAtDate` (optional Date)
- `state.hasAdminConfig`, `state.tokensByModel`, `state.totalCostToday`
- Plant identity colors: pulseSession (cyan), pulseWeekly (lavender), pulseSonnet (gold), pulseOpus (pink), tierLow (green), sessionOrbit (cyan)

## Current State (2026-02-27)
- **On `flower-anemone` branch** — active development
- BreakdownView shows 3 big anemones (no stalks/garden, just flowers on starfield + fog)
- `FlowerRenderer` in `FlowerTestView.swift` has 3 anemone variants + shared eye:
  - `drawDeepSea` (Session/cyan) — 14-18 thin fast tentacles, small tip dots
  - `drawCrown` (Weekly/lavender) — 8-10 thick tentacles, large bulbous tips, collar ring
  - `drawSpiral` (Sonnet/gold) — 12 corkscrewing tentacles, trailing wisps, slow rotation
- All take `brightness` param for hover (1.0 normal, 1.5 hovered)
- BreakdownView limits to `allBuckets.prefix(3)` for consistency with OrreryView/PulseView
- Old garden code (stalks, tendrils, mycelium, spores) still in file but not called — ready to re-integrate once flowers are finalized
- `FlowerTestView` has slider test harness showing all 3 variants at detail + garden scale

## Known Bugs (all fixed)
- ~~Labels only show for Crown (center)~~ — Fixed: 2-pass rendering (flowers first, labels second)
- ~~Percentage text in eye orbs looks bad~~ — Fixed: moved % below the short label

## Branches
- `main` — safe checkpoint with all 3 original flower prototypes (Anemone/Lotus/Nebula) + docs
- `flower-anemone` — 3 anemone variants integrated, big flowers layout (active)
- `flower-lotus` — parked for Void Lotus alternative

## Adding Files to Xcode Project
New `.swift` files must be added to `Helios.xcodeproj/project.pbxproj`:
1. PBXFileReference entry (sourcecode.swift, sourceTree `<group>`)
2. PBXBuildFile entry referencing the file ref
3. Add to PBXGroup (Helios source group)
4. Add to PBXSourcesBuildPhase

## References
- `RESEARCH.md` — SwiftUI visual effects (Canvas, Metal shaders, particles, Nano Banana)
- `TODO.md` — feature backlog and planet texture integration steps
