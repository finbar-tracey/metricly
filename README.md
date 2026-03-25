# Metricly

A clean, focused gym tracker for iOS built with SwiftUI and SwiftData.

![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![Platform](https://img.shields.io/badge/Platform-iOS_18+-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

**Workout Logging**
- Create workouts with exercises, sets, reps, and weight
- Quick-log from your last session with one tap
- Weight auto-fills and increment buttons for fast entry
- Warm-up sets, supersets, and exercise reordering
- Save workouts as reusable templates

**Progress Tracking**
- Personal record detection with celebration banner
- Per-exercise progression charts (max weight over time)
- Weekly volume bar chart
- Workout streak counter
- Training calendar with monthly view

**Body Weight**
- Log daily weigh-ins
- Trend line chart with 30-day change stats

**Rest Timer**
- Configurable rest timer between sets
- Background notifications when timer completes
- Audible alert sound
- Adjustable (+/- 15s) mid-countdown

**Data & Export**
- CSV export of all workout data
- iCloud sync ready via CloudKit
- No account required

## Tech Stack

- **SwiftUI** — declarative UI
- **SwiftData** — persistence with `@Model`, `@Query`, `@Relationship`
- **Swift Charts** — volume, progression, and body weight charts
- **UserNotifications** — background rest timer alerts
- **AudioToolbox** — in-app timer completion sound

## Architecture

```
tracker/
├── Models/
│   ├── Workout.swift          # Core workout model with duration & rating
│   ├── Exercise.swift         # Exercise with muscle group categories
│   ├── ExerciseSet.swift      # Set with warm-up support
│   ├── BodyWeightEntry.swift  # Daily weigh-in entries
│   ├── UserSettings.swift     # Preferences (units, rest timer, onboarding)
│   └── WeightUnit.swift       # kg/lbs with environment key
├── Views/
│   ├── ContentView.swift      # Home screen with streak stats & search
│   ├── WorkoutDetailView.swift    # Exercise list, supersets, duration
│   ├── ExerciseDetailView.swift   # Set logging, quick-log, rest timer, PR detection
│   ├── ExerciseHistoryView.swift  # History & progression chart
│   ├── VolumeChartView.swift      # Weekly volume bar chart
│   ├── BodyWeightView.swift       # Weight logging & trend chart
│   ├── WorkoutCalendarView.swift  # Monthly training calendar
│   ├── SettingsView.swift         # Preferences, templates, CSV export
│   ├── OnboardingView.swift       # First-launch welcome flow
│   ├── FinishWorkoutSheet.swift   # Rating & notes on completion
│   ├── AddWorkoutSheet.swift      # New workout with template picker
│   ├── EditWorkoutSheet.swift     # Edit name, date, notes
│   ├── EditSetSheet.swift         # Edit reps & weight
│   ├── ShareSheet.swift           # UIActivityViewController wrapper
│   └── ExportHelper.swift         # CSV generation
└── trackerApp.swift           # App entry point with model container
```

## Requirements

- iOS 18.0+
- Xcode 16.0+
- Swift 6.0

## Getting Started

1. Clone the repo
2. Open `tracker.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and run on a device or simulator

## License

MIT License — see [LICENSE](LICENSE) for details.
