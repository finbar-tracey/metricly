# Changelog

All notable changes to Metricly are documented here.

---

## v1.4 — 2026-05-28

The engine becomes adaptive in a real sense — it now captures
user-reported soreness on every workout finish, observes whether you
follow its recommendations, and feeds both signals back into the next
day's plan. Strava goes both ways. Plenty of behind-the-scenes
hardening too.

### Added
- **Soreness self-report**: After every workout, an optional 0–4 picker
  on each muscle group you trained. The recovery engine treats it as a
  third intensity signal alongside training volume and RPE — if you
  say your legs are sore, legs freshness drops even when the objective
  model thinks they're fine. Visible afterward in Muscle Recovery as
  "Reported Soreness" with the most recent self-report per group.
- **Trust calibration**: The engine now snapshots its own
  recommendations against what you actually did each day. A user who
  has trained through three suggested rest days in a week will see
  today's rest suggestion downgraded to medium confidence with a
  gentle note about the pattern. Confidence and reason copy adjust
  per intensity bucket.
- **Strava cardio sync** (pull): A "Sync from Strava" row in Settings
  imports your recent Strava activities as cardio sessions. Dedupes
  against existing entries by activity ID, skips unsupported types
  (Swim/Hike/Yoga/etc.) with an honest count, and is safe to re-run.
  Existing Strava connections will need a one-time reconnect to grant
  the new `activity:read_all` permission — surfaced as a clear prompt
  if you try to sync with an old token.
- **Adaptive plan transparency**: Each plan's reason list now includes
  the trust-calibration note when applicable, so "medium confidence"
  comes with an explanation.
- **Widget staleness indicator**: An unobtrusive amber dot appears on
  home-screen widgets when the app hasn't foregrounded in 12+ hours,
  so you know the displayed value may be behind reality.
- **Global error banner**: Failures that used to be silent
  (HealthKit save errors, Strava sync errors) now surface a slim
  banner from the top of the screen.

### Fixed
- **Caffeine and Water widgets were silently empty.** Both were
  reading from an unregistered App Group suite — the data they tried
  to load was always isolated from what the main app wrote. Single
  source of truth in the widget extension; both now display live data.
- **Live Activity could be orphaned on the lock screen** for hours
  after a force-quit. Cold launch now reconciles dangling activities:
  re-attaches when the workout is still in progress, ends them
  otherwise.
- **Strava `client_secret` was checked into git.** Moved to a
  gitignored `Secrets.xcconfig` with Xcode build-setting substitution.
  The OAuth flow now also includes a CSRF `state` parameter and uses
  an ephemeral browser session.
- **Future-dated workouts** (from clock drift or manual edits) no
  longer contribute negative fatigue to the recovery engine.
- **CSV imports** from comma-decimal locales (German / French / etc.)
  now parse correctly. Round-trip works from any locale.
- **App Intents** for water and weight now reject implausible values
  with a clear dialog (used to silently log -100 kg if Siri misheard).
- **CardioHub trophy/target toolbar buttons** had no VoiceOver labels.
- **Schema migration scaffolding**: SwiftData is now versioned
  (V1→V2→V3) with explicit lightweight stages, so future schema
  changes are small additive PRs instead of big-bang rewrites.

### Changed
- **HomeDashboard decomposition** (1713 → 531 LOC, no behavior
  change). Every visual card now lives in its own focused file with
  explicit dependencies.
- **WorkoutDetail decomposition** (1033 → 741 LOC). Hero card,
  exercise row, superset picker, and summary formatter all extracted.
- **HealthKit fetches** are cached for 5 minutes per call, invalidated
  when the app foregrounds. Opening Home, then Health, then a detail
  view used to fire three separate queries for the same data; now
  it's one.
- **Widget snapshot models** consolidated into one shared file
  compiled into both targets. Adding a field is a one-line change.
- **Recovery engine constants** centralized into `EngineConstants` —
  RPE thresholds, HRV multipliers, cardio pace zones, fatigue caps,
  and ~30 PersonalInsights tuning knobs. The math is unchanged; the
  knobs are now discoverable and named.
- **Color tokens**: 24 files now use `AppTheme.Signal.*` instead of
  raw `Color(red:green:blue:)` literals.
- **Dynamic Type** support extended to home dashboard sections
  (labels and headers scale with user font-size preference).

### Infrastructure
- **Localization foundation**: User-facing strings in the adaptive
  engine now go through `String(localized:)`. Adding a new language
  becomes a strings-catalog drop rather than a code refactor.
- **Xcode Cloud scaffolding**: `ci_scripts/ci_post_clone.sh`
  materializes `Secrets.xcconfig` from CI env vars; a checked-in
  `tracker.xctestplan` runs the full trackerTests suite. App Store
  Connect setup documented in `ci_scripts/README.md`.

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
