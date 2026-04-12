# Metricly

A clean, focused gym tracker for iOS built with SwiftUI and SwiftData.

![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![Platform](https://img.shields.io/badge/Platform-iOS_18+-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## Screenshots

<p align="center">
  <img src="screenshots/home.png" width="200" />
  <img src="screenshots/workout.png" width="200" />
  <img src="screenshots/exercise.png" width="200" />
  <img src="screenshots/calendar.png" width="200" />
</p>

## Features

**Workout Logging**
- Create workouts with exercises, sets, reps, and weight
- Quick-log from your last session with one tap
- Weight auto-fills and increment buttons for fast entry
- Warm-up sets, supersets, and exercise reordering
- Save workouts as reusable templates
- Workout notes and post-workout rating

**Training Programs**
- Multi-week structured training programs
- Scheduled workout days with auto-progression
- Quick-start today's programmed workout

**Progress Tracking**
- Personal record detection with celebration banner
- Per-exercise progression charts (max weight over time)
- Volume trends with weekly/monthly breakdowns
- Workout streak counter and streak calendar
- Training calendar with monthly view
- Workout comparison (side-by-side sessions)
- Weekly and monthly recap reports

**Recovery & Smart Suggestions**
- Recovery readiness score based on volume, RPE, HRV, sleep, and resting HR
- Per-muscle-group fatigue tracking with multi-session accumulation
- Smart workout suggestions based on recovery state
- Progression advisor with load/rep recommendations

**Health Integration**
- HealthKit sync for HRV, resting heart rate, steps, and sleep
- Health dashboard with daily metrics overview
- Steps, sleep, and heart rate detail views

**Body Tracking**
- Daily weigh-ins with trend line chart and 30-day change stats
- Body measurements (arms, chest, waist, etc.)
- Body fat estimation
- Progress photos with date tagging

**Tools**
- Configurable rest timer with background notifications and audible alert
- Plate calculator for barbell loading
- One-rep max calculator
- Exercise library with muscle group categories
- Exercise guide with form tips and substitutions
- Lift goals with progress tracking

**Achievements**
- Milestone-based achievement system
- Streak, volume, and PR achievements

**Data & Export**
- CSV export and import of workout data
- Workout share cards (image export)
- iCloud sync ready via CloudKit
- Siri shortcuts for common actions
- Workout reminders
- No account required

## Tech Stack

- **SwiftUI** — declarative UI
- **SwiftData** — persistence with `@Model`, `@Query`, `@Relationship`
- **Swift Charts** — volume, progression, body weight, and health charts
- **HealthKit** — HRV, resting HR, steps, and sleep data
- **UserNotifications** — background rest timer alerts and reminders
- **AudioToolbox** — in-app timer completion sound
- **App Intents** — Siri shortcuts

## Architecture

```
tracker/
├── Models/
│   ├── Workout.swift              # Core workout model with duration & rating
│   ├── Exercise.swift             # Exercise with muscle group categories
│   ├── ExerciseSet.swift          # Set with warm-up & RPE support
│   ├── BodyWeightEntry.swift      # Daily weigh-in entries
│   ├── BodyMeasurement.swift      # Body measurements (arms, chest, etc.)
│   ├── ProgressPhoto.swift        # Progress photo entries
│   ├── TrainingProgram.swift      # Multi-week training programs
│   ├── LiftGoal.swift             # Lift goal targets
│   ├── ExerciseGuide.swift        # Exercise form guides & tips
│   ├── WorkoutActivity.swift      # Live Activity support
│   ├── RecoveryEngine.swift       # Recovery scoring (volume, RPE, HRV, HR, sleep)
│   ├── ProgressionAdvisor.swift   # Load/rep progression suggestions
│   ├── HealthFormatters.swift     # Shared formatting for steps, sleep, etc.
│   ├── UserSettings.swift         # Preferences (units, rest timer, onboarding)
│   └── WeightUnit.swift           # kg/lbs with environment key
├── Views/
│   ├── HomeDashboardView.swift        # Home dashboard with recovery, health, recents
│   ├── ContentView.swift              # Tab root with streak stats & navigation
│   ├── WorkoutDetailView.swift        # Exercise list, supersets, duration
│   ├── ExerciseDetailView.swift       # Set logging, quick-log, rest timer, PR detection
│   ├── ExerciseHistoryView.swift      # History & progression chart
│   ├── ExerciseLibraryView.swift      # Browsable exercise database
│   ├── ExerciseGuideView.swift        # Exercise form guide & tips
│   ├── ExerciseSubstitutionsView.swift# Alternative exercise suggestions
│   ├── FullWorkoutListView.swift      # Complete workout history list
│   ├── VolumeTrendsView.swift         # Weekly/monthly volume charts
│   ├── MuscleRecoveryView.swift       # Per-muscle recovery status
│   ├── MuscleGroupSummaryView.swift   # Muscle group volume breakdown
│   ├── SmartSuggestionsView.swift     # AI-driven workout suggestions
│   ├── InsightsView.swift             # Training insights & analytics
│   ├── HealthDashboardView.swift      # HealthKit metrics overview
│   ├── HeartRateDetailView.swift      # Heart rate trends
│   ├── StepsDetailView.swift          # Daily steps detail
│   ├── SleepDetailView.swift          # Sleep tracking detail
│   ├── BodyWeightView.swift           # Weight logging & trend chart
│   ├── BodyMeasurementsView.swift     # Body measurement tracking
│   ├── BodyFatEstimateView.swift      # Body fat estimation tool
│   ├── ProgressPhotosView.swift       # Progress photo gallery
│   ├── PersonalRecordsView.swift      # PR history & records board
│   ├── WorkoutCalendarView.swift      # Monthly training calendar
│   ├── StreakCalendarView.swift       # Workout streak visualization
│   ├── WorkoutComparisonView.swift    # Side-by-side workout comparison
│   ├── WeeklyRecapView.swift          # Weekly training summary
│   ├── WeeklyMonthlyReportView.swift  # Detailed periodic reports
│   ├── TrainingProgramsView.swift     # Training program management
│   ├── LiftGoalsView.swift            # Lift goal tracking
│   ├── OneRepMaxView.swift            # 1RM calculator
│   ├── PlateCalculatorView.swift      # Barbell plate calculator
│   ├── AchievementsView.swift         # Achievement badges & milestones
│   ├── WorkoutTimerView.swift         # Rest timer interface
│   ├── WorkoutNotesView.swift         # Workout notes editor
│   ├── TemplateEditView.swift         # Workout template editor
│   ├── TemplateMarketplaceView.swift  # Browse shared templates
│   ├── SettingsView.swift             # Preferences, templates, CSV export
│   ├── OnboardingView.swift           # First-launch welcome flow
│   ├── FinishWorkoutSheet.swift       # Rating & notes on completion
│   ├── AddWorkoutSheet.swift          # New workout with template picker
│   ├── EditWorkoutSheet.swift         # Edit name, date, notes
│   └── EditSetSheet.swift             # Edit reps & weight
├── Services/
│   ├── HealthKitManager.swift     # HealthKit data fetching & permissions
│   ├── HapticsManager.swift       # Haptic feedback
│   ├── WorkoutActivityManager.swift # Live Activity management
│   ├── ReminderManager.swift      # Workout reminder scheduling
│   └── AppShortcuts.swift         # Siri shortcut definitions
├── Helpers/
│   ├── ExportHelper.swift         # CSV generation
│   ├── ImportHelper.swift         # CSV import parsing
│   └── QuickStartHelper.swift    # Quick-start workout logic
├── Components/
│   ├── WorkoutCardView.swift      # Shared workout list card
│   ├── WorkoutShareCardView.swift # Shareable workout image card
│   ├── QuickStartCard.swift       # Quick-start UI card
│   ├── FlowLayout.swift           # Wrapping tag layout
│   └── ShareSheet.swift           # UIActivityViewController wrapper
└── trackerApp.swift               # App entry point with model container
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
