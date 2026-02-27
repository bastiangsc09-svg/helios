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
- BreakdownView temporarily shows `FlowerTestView` for flower design selection
- `FlowerRenderer` enum has 3 static draw methods (Anemone, Void Lotus, Nebula Bloom) + shared eye orb
- To revert BreakdownView: change `body` back to `originalBody` content (ZStack with gardenView/emptyState)
- The chosen flower design replaces `drawBloom()` in BreakdownView

## Branches
- `main` — checkpoint with all 3 flower prototypes
- `flower-anemone` — Anemone bloom integration (active development)
- `flower-lotus` — Void Lotus bloom integration (alternative)

## Adding Files to Xcode Project
New `.swift` files must be added to `Helios.xcodeproj/project.pbxproj`:
1. PBXFileReference entry (sourcecode.swift, sourceTree `<group>`)
2. PBXBuildFile entry referencing the file ref
3. Add to PBXGroup (Helios source group)
4. Add to PBXSourcesBuildPhase

## References
- `RESEARCH.md` — SwiftUI visual effects (Canvas, Metal shaders, particles, Nano Banana)
- `TODO.md` — feature backlog and planet texture integration steps
