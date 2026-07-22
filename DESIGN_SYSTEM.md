# Metricly — Design System ↔ Code Map

Bridges the Figma component library to the SwiftUI source. (Figma's native *Code
Connect* needs an Enterprise Developer seat, so this doc + the per-component Figma
`description` fields serve the same purpose on our plan.)

- **Figma file:** `WvO340N5HmLHKnUESPtmmB`
- **Design System page:** "🎨 Design System" — token board + 12 components.
- **Gallery page:** "📱 Final Screens" (id 49:2) — 48 rendered screens in category swimlanes.

## Tokens (Figma Variables/Styles → AppTheme.swift)

| Figma | Type | AppTheme |
|---|---|---|
| `color/recovery … alarmRed` | Color var (collection "Tokens") | `AppTheme.Signal.*` |
| `color/cardHairline`, `color/chartGrid` | Color var | `AppTheme.cardHairline`, `AppTheme.chartGrid` |
| `radius/hero card miniCard tile chip` | Float var | `AppTheme.heroRadius … chipRadius` (28/20/16/14/10) |
| `spacing/section cardPadding tilePadding` | Float var | `AppTheme.sectionSpacing/cardPadding/tilePadding` (28/18/14) |
| `Gradient/Recovery Caution Strain Calm` | Paint Style | `AppTheme.Gradients.*` |

Variable collection has **Light + Dark** modes (Dark currently mirrors Light — to tune
in a dark-mode pass).

### Redesign tokens (`design_handoff_app` — dark, signal-glow)

A second, parallel palette introduced by the Home redesign. Not yet in Figma —
source of truth is `DesignTokens/MetriclyTokens.swift`, which is compiled into
**both** the app and the widget extension so the brand has one definition.

| Token group | Symbol | Notes |
|---|---|---|
| Surfaces (bg, bgInset, surface, surfaceLo, surfaceHi, hairline) | `AppTheme.Dark.*` | "Calm pass" values — one step lighter than the v1 handoff |
| Text scale (text … text4, ink) | `AppTheme.Dark.*` | `ink` is the near-black used *on* accent fills |
| Signals (recovery, strain, caution, focus, calm) | `AppTheme.Dark.Signal.*` | Tuned to glow on the deep neutrals; unchanged by the calm pass |
| Radii (hero 22, card 18, well 12, chip 8, bar 3) | `AppTheme.Dark.Radius.*` | Tighter than the app-wide `AppTheme.*Radius` scale |
| Cross-target brand colors | `MetriclyBrand.runOrange / alarmRed / workout` | Shared with `MetriclyWidgets` — was 5 duplicated RGB literals |
| Glow / chrome / entrance motion | `.signalGlow(_:)`, `.darkCard()`, `.darkWell()`, `.growIn()` | `growIn` honours Reduce Motion (skips the animation, keeps the end state) |

Scoped to the **Home tab only** — applied via `.environment(\.colorScheme, .dark)`
in `homeDashboardChrome`, not `.preferredColorScheme` (which propagates to the
window, where `ContentView`'s root value wins). Other tabs stay on the adaptive
palette driven by the Settings appearance toggle.

| Redesign component | SwiftUI source | Design ref |
|---|---|---|
| EffortTape (14-day strip) | `tracker/Components/EffortTape.swift` | `tape-v2.jsx` → `TapeEffort` |
| TodayHero (verdict banner) | `tracker/Components/TodayHero.swift` | `tape-v2.jsx` → `HomeWithTape` |
| MicroSignalRow (4-up signals) | `tracker/Components/MicroSignalRow.swift` | `tape-v2.jsx` → `MicroSignal` |
| NextUpCard (session on deck) | `tracker/Components/NextUpCard.swift` | `tape-v2.jsx` → `ExerciseRowV2` |
| Composition + data mapping | `tracker/Views/HomeTodaySection.swift` | `scenario.jsx` (presentation state, not an engine) |

## Components (Figma node → SwiftUI)

| Figma component | node | SwiftUI source | symbol | status |
|---|---|---|---|---|
| HeroCard | 114:61 | `tracker/DesignSystemKit.swift` | `HeroCard` | ✅ shared |
| GradientProgressBar | 114:97 | `tracker/AppTheme.swift` | `GradientProgressBar` | ✅ shared |
| SectionHeader | 114:89 | `tracker/AppTheme.swift` | `SectionHeader` | ✅ shared |
| StatCol | 114:93 | `tracker/AppTheme.swift` | `HeroStatCol` | ✅ shared |
| HubRow | 114:100 | `Components/HubRow.swift` | `hubRow` | ✅ shared |
| InsightCard | 115:52 | `tracker/Views/InsightCardView.swift` | `InsightCardView` | ✅ shared |
| AdaptivePlanCard | 115:94 | `tracker/Views/AdaptivePlanCardView.swift` | `AdaptivePlanCardView` | ✅ shared |
| ContextualCTA | 115:110 | `tracker/Views/HomeContextualCTASection.swift` | `HomeContextualCTASection` | ✅ shared |
| GradientDisc | 114:22 | `tracker/DesignSystemKit.swift` | `GradientDisc` / `gradientDisc(_:)` | ✅ **extracted** (colorScheme-aware) |
| TintedCallout | 114:87 | `tracker/DesignSystemKit.swift` | `.tintedCallout(_:)` | ✅ **extracted** (colorScheme-aware) |
| BadgePill | 114:39 | `tracker/DesignSystemKit.swift` | `.gradientCapsule(_:)` | ✅ **extracted** (colorScheme-aware) |
| FilterChip | 114:47 | `tracker/DesignSystemKit.swift` | `FilterChip` | ✅ **extracted** (Library + Achievements route through it) |

## Parallel SwiftUI extraction (the ⚠️ rows) — post-release task

Extracting the ⚠️ components keeps design↔code 1:1 and removes real duplication:

1. ✅ **`GradientDisc`** — shared `View` + `gradientDisc(_:color:size:glyph:)` in
   `DesignSystemKit.swift`; the 3 private helpers removed. colorScheme-aware. *(done)*
2. ✅ **`.tintedCallout(_ color:)`** modifier in `DesignSystemKit.swift`; inline chrome
   removed from InsightCardView / TopInsightCardView / InsightsTeaseCard. colorScheme-aware. *(done)*
3. ✅ **`.gradientCapsule(_ color:)`** modifier (BadgePill chrome) in `DesignSystemKit.swift`;
   migrated insight strength/pattern badges + AdaptivePlan intensity pill. colorScheme-aware. *(done)*
4. ✅ **`FilterChip`** view in `DesignSystemKit.swift`; ExerciseLibrary + Achievements route
   through it (Achievements upgraded from solid- to gradient-selected for consistency). *(done)*

**All 4 shared components extracted — the Figma library is now 1:1 with code.**

**Dark mode** is wired: Appearance toggle (Light/Dark/System) in Settings → root
`.preferredColorScheme`. All extracted components are colorScheme-aware (opacities step up
on dark); the caffeine decay chart lightens brown→amber on dark.

Recipe constants (match the Figma components): disc gradient `color@0.26→0.12` + stroke
`@0.30`; callout wash `@0.10→clear` + border `@0.20`; badge `@0.20→0.10` + stroke `@0.25`.
