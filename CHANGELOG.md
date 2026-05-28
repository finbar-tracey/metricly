# Changelog

All notable changes to Metricly are documented here.

---

## v1.5 — Unreleased

The adaptive plan reaches the wrist, the Insights tab learns to talk
about plan compliance, and a methodical sweep across the engine + view
layers — driven by a fresh top-to-bottom review — removes drift,
duplicate state, and a handful of latent bugs.

### Added
- **Compliance card on Insights**: A new "Plan compliance" card on the
  Patterns tab summarises how often you followed the engine's
  intensity recommendation over the last week. Coloured progress bar
  (green ≥70%, amber ≥50%, red below) and a footnote naming the most-
  often-skipped bucket ("Most often skipped: rest days (3)") so the
  feedback loop is observable, not just internal.
- **Watch shows today's adaptive plan**: The Watch start screen and
  every watch-face complication family (rectangular, inline, circular,
  corner) now read the engine's recommendation — not the schedule
  label — so a "Push Day" that the engine downgraded to "Recovery"
  shows as "Recovery" on the wrist too. Intensity badges (LIGHT / HARD)
  appear on the watch face for non-default days; moderate stays
  unmarked.
- **Onboarding: adaptive coach page**: New page between Features and
  Profile that explains the three ideas behind the adaptive engine —
  "Tell it how you feel" (soreness), "It watches whether you listen"
  (trust calibration), "Patterns surface over time" — so new users
  know the app is observing them rather than just storing reps.

### Fixed
- **Skip-HealthKit button advanced to the wrong page** after the
  onboarding renumbering — the page indicator stayed on Health and
  the in-page Skip got hidden a page early.
- **Plan compliance treated moderate↔hard as compliant**, hiding the
  exact overtraining pattern (always pushing moderate days to hard)
  that trust-cal needs to see to learn. Doc-comment said one thing,
  code did another; now both agree only `.light ↔ .moderate` is a
  soft match.
- **HRV and resting-HR confidence without a baseline**: An isolated
  today's reading with no rolling baseline was counting as a "health
  signal" and silently nudging confidence to medium. Now requires the
  same `today + baseline` pair the reason-text branch already
  requires.
- **Phone-side workout starts didn't refresh widgets** until the next
  scheduled timeline reload (30–60 min). `publishActiveWorkout` now
  calls `WidgetCenter.reloadAllTimelines()` immediately.
- **Watch saw a phantom "On iPhone" banner** during its own session
  whenever the phone foregrounded — the round-trip through
  `collectWatchContext` was overwriting the watch's published active
  state before the source-guard kicked in.
- **Watch cold-launch could silently drop the phone-active banner**
  when the `activeSource` key was missing — now treats an unset
  source as "phone" rather than "ignore".
- **Lock-screen and StandBy widgets** ignored the stale-data pill
  added in v1.4. Now apply it for every family — circular, inline,
  rectangular, and the standalone streak widget.
- **Indoor Walks from the watch round-tripped as outdoor walks** —
  `WatchCardioType` was missing the `indoorWalk` case so the reverse
  mapping collapsed both walking variants.
- **Watch's global rest timer fallback was stuck at 60s** regardless
  of the user's iPhone setting — the App Group key it was reading was
  never written by the phone. Now plumbed through `collectWatchContext`.
- **VoiceOver read SwiftUI color debug strings** on the recovery hero
  card — `accessibilityHint(color.description)` was sending
  `"AnyShapeStyle(...)"` to the screen reader. Replaced with a proper
  combined element + localized "Overall readiness 78 percent. Mostly
  recovered. Light to moderate training recommended."
- **Strava 401 (stale token) and 429 (rate limit)** now surface
  actionable banner copy — "Reconnect Strava..." and "Strava is
  rate-limiting us — try again in 15 minutes" — instead of a generic
  failure.
- **trackerTests target deployment-target mismatch** broke CI
  silently — bumped to iOS 26.0 to match the host app module.

### Changed
- **GroupedListCard component**: Four MuscleRecoveryView cards
  (Health Factors, External Activity, Reported Soreness, By Muscle
  Group) used to rebuild the same `SectionHeader + tinted background
  + clipShape + appCard()` shell independently. Collapsed to one
  shared component.
- **PersonalInsightsEngine `now:` injection**: Every cutoff
  computation now anchors on `inputs.now` (default `.now`) for
  deterministic tests, matching the convention already in
  `RecoveryEngine` and `TodayPlanEngine`. Two shared helpers
  (`finishedWorkouts(in:withinDays:)`, `topExerciseName(in:minHits:)`)
  collapse 11 duplicated filter / top-frequency sites.
- **ComplianceBackfill thresholds** (20 sets / 2000 kg / 60 min hard,
  ≤8 sets ∧ ≤30 min light) moved into a new `EngineConstants.Compliance`
  namespace so they can't drift away from the forward-direction
  TodayPlan thresholds.
- **Soreness color ramp consolidated** on `SorenessEntry.Level`. Both
  the capture sheet and the readout card used to declare identical
  5-level RGB ramps independently.
- **App-group identifier consolidated** behind `WidgetAppGroup.suiteName`
  in 8 sites (was hardcoded as `"group.com.Finbar.FinApp"`). The
  watch app target keeps its own mirror under `WatchSharedKeys.suite`
  with a cross-reference comment.
- **AppTheme palette** gained `Signal.warning` (system yellow) — the
  missing middle stop on traffic-light ramps. Four files migrated
  off raw color literals onto AppTheme tokens.
- **Onboarding clamped to xxLarge Dynamic Type** — chrome surface
  with hand-tuned hero compositions stays recognisable at AX1–AX5
  without rewriting every page to use Dynamic-Type-aware fonts.
- **Sprint 12-13 strings localized** (~80 user-facing strings across
  MuscleRecoveryView, FinishWorkoutSheet, PersonalInsightsView, and
  StravaSettingsSection) — Sprint 11's `String(localized:)` migration
  hadn't covered the parallel feature work.

### Infrastructure
- **38 new tests** across `ComplianceBackfillTests` (idempotency,
  boundary, lookback), `MetriclySchemaMigrationTests` (V1→V3
  round-trip on a real SQLite file), `StoreRoundTripTests` (history
  window dedup, prune, lookup), `StravaErrorPresenterTests` (status
  → reason mapping, anti-swap regression), and new pins on
  `WatchSyncModelsTests` for the three adaptive-plan keys.
- **`StravaErrorPresenter` extracted** from `StravaSettingsSection` so
  the 401/429/generic mapping is unit-testable without standing up
  the whole view + bus.
- **Soreness/CardioType/CardioType-rawValue test pins**: a number of
  stale assertions from earlier sprints (testing aspirational vs
  actual rawValues) corrected to match shipped contracts.

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
