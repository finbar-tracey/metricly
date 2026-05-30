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
| GradientDisc | 114:22 | `WaterTrackerView` / `CaffeineTrackerView` / `CreatineTrackerView` + ~8 inline copies | `gradientDisc` (private helper) | ⚠️ **duplicated — extract** |
| BadgePill | 114:39 | inline in TopInsightCardView / InsightCardView / etc. | — | ⚠️ **no shared symbol — extract** |
| TintedCallout | 114:87 | inline in TopInsightCardView / InsightCardView / InsightsTeaseCard / OnboardingView | — | ⚠️ **extract `.tintedCallout(_:)`** |
| FilterChip | 114:47 | inline in ExerciseLibraryView / AchievementsView / Insights tabs | `filterChip` (varies) | ⚠️ **varies per screen — unify** |

## Parallel SwiftUI extraction (the ⚠️ rows) — post-release task

The four ⚠️ components have no single source of truth in code. Extracting them keeps
design↔code 1:1 and removes real duplication:

1. **`GradientDisc`** — one shared `View` (or `.gradientDisc(color:size:icon:)` modifier)
   in `DesignSystemKit.swift`; replace the copied `gradientDisc` helpers + inline ZStacks.
2. **`.tintedCallout(_ color:)`** modifier — the wash (`color@0.10→clear`) + tinted border
   (`color@0.20`) chrome; replace the 4 inline copies.
3. **`BadgePill`** view — gradient capsule (`color@0.20→0.10`) + icon + label.
4. **`FilterChip`** view — unify the per-screen filter-chip implementations.

Recipe constants (match the Figma components): disc gradient `color@0.26→0.12` + stroke
`@0.30`; callout wash `@0.10→clear` + border `@0.20`; badge `@0.20→0.10` + stroke `@0.25`.
