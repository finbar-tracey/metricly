# Changelog

All notable changes to Metricly are documented here.

---

## v1.3 — 2026-04-26

### Added
- **Activity Log**: Log non-gym activities (walks, bike rides, stretching, yoga, swimming, hiking, etc.) with duration and optional calories
- **Workout Timers on Workout Screen**: Stopwatch button in WorkoutDetailView toolbar for quick access to EMOM, AMRAP, and Tabata timers
- **RPE on Workout View**: Average RPE now shown per exercise in workout exercise list
- **Change Category in Exercise Library**: Long-press any exercise in the library to change its muscle group category (moved from exercise detail menu)

### Changed
- **Home Dashboard**: Health glance cards now use a 2-column grid layout instead of horizontal scroll
- **Quick Log**: Section is now collapsible (tap header to expand/collapse)
- **Rest Timer**: No longer auto-starts after adding sets; use the stopwatch toolbar button to manually start the rest timer
- **Substitutions**: Removed from exercise detail menu (accessible via Exercise Guide)

### Fixed
- Updated feedback email and App Store link in Settings

---

## v1.2 — 2026-04-26

### Added
- **Water Tracker**: Adjustable daily goal (in Settings), weekly stats (avg intake, days at goal), hydration streak, time-of-day breakdown, 7D/30D history chart with goal line, undo snackbar
- **Creatine Tracker**: Loading phase mode (20g/day, 4 tracked doses), configurable dose in Settings, weekly compliance percentage with progress bar, 30-day intake chart, undo snackbar
- **Caffeine Tracker**: Sensitivity setting (Slow/Normal/Fast metabolism), configurable daily limit, 11 drink presets (up from 6), real-time decay chart, quick-log favorites, sleep correlation analysis, weekly averages, caffeine-free streak, peak caffeine time
- **Onboarding**: Profile setup page (name, weight unit, weekly goal, water goal), HealthKit permission prompt with skip option
- **Home Dashboard**: Water progress and creatine status cards in health glance row
- **Settings**: Water section (daily goal stepper), Creatine section (dose, loading phase toggle), Caffeine section (sensitivity, daily limit)
- **Feedback**: Updated support email and App Store link

---

## v1.1 — 2026-04-25

### Added
- Water tracker with progress ring, presets, and 7-day chart
- Creatine tracker with daily check-in, streak stats, and 28-day calendar
- Caffeine tracker with basic logging
- Toolbar icon migration (stopwatch + plate calc moved to ExerciseDetailView)
- Explicit model container registration for all SwiftData models

### Fixed
- Removed orphaned rest timer state from WorkoutDetailView
- Fixed model container missing Exercise, ExerciseSet, ProgramDay, ProgramExercise

---

## v1.0 — Initial Release

### Features
- Workout logging with exercises, sets, reps, and weight
- Quick-log from last session, weight auto-fill, increment buttons
- Warm-up sets, supersets, exercise reordering
- Workout templates
- Multi-week training programs with auto-progression
- Personal record detection with celebration banner
- Per-exercise progression charts, volume trends
- Workout streak counter and calendar
- Workout comparison (side-by-side sessions)
- Weekly and monthly recap reports
- Recovery readiness scoring (volume, RPE, HRV, sleep, HR)
- Per-muscle-group fatigue tracking
- Smart workout suggestions and progression advisor
- HealthKit integration (HRV, resting HR, steps, sleep)
- Health dashboard with detail views
- Body weight tracking with trend chart
- Body measurements and body fat estimation
- Progress photos
- Rest timer with background notifications
- Plate calculator and one-rep max calculator
- Exercise library with muscle group categories
- Exercise guide with form tips and substitutions
- Lift goals with progress tracking
- Achievement system (streaks, volume, PRs)
- CSV export/import
- Workout share cards
- Siri shortcuts
- Workout reminders
