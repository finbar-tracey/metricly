# Metricly — agent guide

## Targets

| Target | Path | Role |
|--------|------|------|
| tracker | `tracker/` | iPhone/iPad app |
| MetriclyWatch | `MetriclyWatch/` | watchOS app |
| MetriclyWidgetsExtension | `MetriclyWidgets/` | Widgets + Live Activity |
| trackerTests | `trackerTests/` | XCTest (engines, migrations, import) |
| trackerUITests | `trackerUITests/` | UI smoke tests (optional in test plan) |

## Build & test

```sh
open tracker.xcodeproj
xcodebuild test -scheme tracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -testPlan tracker
```

Shared schemes: `tracker`, `MetriclyWidgetsExtension`.

## Architecture

- **SwiftData** schema: `Services/MetriclySchema.swift`
- **Engines** (pure): `tracker/Models/Engines/`
- **Stores**: `tracker/Models/Stores/`
- **Services** (IO): `Services/` — HealthKit, Strava, connectivity, widgets
- **Sync**: `MetriclySyncCoordinator`, `AppLifecycleCoordinator`, `WatchContextBuilder`, `WatchPayloadPersistence`, `PhoneConnectivityManager`
- **Appearance**: `UserSettings.appearanceMode` only (`AppearanceMode` helper)
- **Routing**: `AppRouter` via `appServices.router` in `ContentView` and feature views; `AppRouter.shared` only in `trackerApp` bootstrap
- **DI**: `AppServices` (`router`, `phoneConnectivity`, `strava`, `workoutActivity`, `healthKit`, `healthDataCache`, `appErrorBus`, `syncStatus`, `cardioTracker`, `openURL` / `openSettings`) via `@Environment(\.appServices)`; exceptions: `UIApplication` for keyboard/resign, window scene in cardio share, `AppServices.shared` in app bootstrap and `HomeSyncStatusPill.shouldShow`, `StravaSettingsSection` preview default.
- **AE–AH (last refactor wave)**: section round 3 (`StreakCalendar*`, `CardioGoals*`, `HeartRateDetail*` splits); coordinators `FullWorkoutListView`, `TrainingProgramsView`, `SmartSuggestionsView` + `SmartSuggestionsEngine`, `WorkoutDetailScreenSections`; maintenance mode — split only when editing files >350 LOC
- **App shell**: `ContentView` + `ContentView+*.swift` extensions (tabs, iPad/iPhone layout, lifecycle)
- **Timers**: `RestTimerController` (rest), `WorkoutDurationTracker` (elapsed workout), `WorkoutIntervalTimerController` (EMOM/AMRAP/Tabata)
- **Home**: `HomeDashboardQueryContainer` holds all `@Query`; `HomeDashboardScreen` is query-free
- **Health details**: `MetricDetailScaffold` on Steps, HR, Water (chart), Sleep, Caffeine (history)
- **Reports**: `WeeklyMonthlyReportEngine` + split `WeeklyMonthlyReport*Sections`; slim `WeeklyMonthlyReportView`
- **Time ranges**: `DetailTimeRange` (7D/30D/90D) on health details; `VolumeTrendPeriod` (weekly/monthly) on `VolumeTrendsView`
- **Workout detail**: `WorkoutDetailQueryContainer` + slim `WorkoutDetailScreen`; sections under `tracker/Views/Workout/`
- **Finish workout**: `FinishWorkoutSummarySection` + `FinishWorkoutFeedbackSection`; slim `FinishWorkoutSheet`
- **Caffeine / Creatine / Body weight**: `CaffeineEngine`, `CreatineEngine`, `BodyWeightEngine` + `CaffeineLoggingSections` / `CaffeineHistorySections` (facade `CaffeineTrackerSections`) under `tracker/Views/Nutrition/`; slim coordinators
- **Sleep / Steps / Water detail**: `SleepEngine` (optional), `SleepDetailSections`, `StepsDetailSections`, `WaterTrackerSections` under `tracker/Views/Health/`
- **Activity / Workout compare**: `ActivityLog*Section`, `WorkoutComparisonSections` under `tracker/Views/Activity/` and `Workout/`
- **Cardio active**: `CardioActiveMapSection` + `CardioActiveMetricsSection` + `CardioActiveControlsSection`; slim `CardioActiveView`
- **Cardio / training hubs**: `CardioHubSections`, `CardioGoalsSections`, `TrainingProgramsSections`, `OneRepMaxSections` + `OneRepMaxEngine`
- **Exercise / progress**: `ExerciseHistorySections`, `ProgressPhotosSections`
- **Cardio session detail**: `CardioSessionDetailSections` + `CardioSessionMapSection` + `CardioSessionActionsSection`
- **Achievements / Cardio bests**: `AchievementsEngine` + section views; `CardioBestsSummarySection` + `CardioBestsRecordsSection`
- **Heart rate detail**: `HeartRateDetailSections` + slim `HeartRateDetailView`
- **Muscle recovery**: `MuscleRecoverySections` + slim `MuscleRecoveryView`
- **Body fat / Streak calendar**: `BodyFatEstimateSections`, `StreakCalendarSections` + slim coordinators
- **Health hub / Patterns**: `HealthDashboardSections`, `PersonalInsightsSections` + slim coordinators
- **Onboarding**: per-page views under `tracker/Views/Onboarding/`; coordinator in `OnboardingView`
- **Settings**: section views under `tracker/Views/Settings/`
- **Watch**: `WatchContextBuilder` in `Services/WatchContextBuilder.swift`
- **Widgets**: views call `MetriclySyncCoordinator` only (not `WidgetDataWriter` directly)
- **Section modules**: large detail UIs split into hero/chart/card files with thin forwarding enums (e.g. `CaffeineLoggingHeroSections`, `SleepDetailChartTrendSections`); second-pass trims keep implementation files ≤ ~350 LOC
- **Workout utilities (AA)**: `TrainingHubSections`, `VolumeTrendsSections` + `VolumeTrendsEngine`, `HomeDashboardScreen+Cards` / `+Lifecycle`, `TrainingBlockDetailSections`, `WorkoutTimerSections`, `BodyMeasurementsSections` + `BodyMeasurementsEngine`, `PlateCalculatorSections` + `PlateCalculatorEngine`, `WorkoutCalendarSections` — coordinators under ~200 LOC
- **HealthKit / connectivity (AC)**: `Services/HealthKit/` (`HealthKitMetricsFetcher`, `HealthKitWorkoutWriter`, `HealthKitCardioWriter`, `HealthKitSleepModels`) + slim `HealthKitManager` facade; `PhoneConnectivityMessageHandler`, `PhoneConnectivityManager+Session` + slim `PhoneConnectivityManager`
- **Strava (AH)**: `Services/Strava/` (`StravaAPIClient`, `StravaAuth`, `StravaUpload`, `StravaTokenRefresher`) + slim `StravaService` facade at `Services/StravaService.swift`
- **Import (AH)**: `ImportHelper` (plan + CSV utilities), `ImportCommit` (SwiftData insert), `ImportParsers` (Strong/Hevy), `ImportFormats` (IR + detect)
- **Watch gym (AH)**: `WatchGymSections`, `WatchGymControlsSections`, `WatchGymSetListSections` + slim `WatchGymView`
- **MetriclyCore package**: still deferred (post AE–AH re-audit) — gate unchanged: `WatchSyncModels` + `WidgetModels` are multi-target shared DTOs; `WatchModels` documents watch-only App Group keys (no fourth duplicated formatter/DTO body). Revisit when a fourth shared copy appears.
- **CI**: PRs — `trackerTests` ([`xcodebuild-test.yml`](.github/workflows/xcodebuild-test.yml)), SwiftLint strict on macOS CI ([`swiftlint.yml`](.github/workflows/swiftlint.yml), config `.swiftlint.yml`); nightly full plan ([`xcodebuild-test-nightly.yml`](.github/workflows/xcodebuild-test-nightly.yml))
- **UI smoke**: `WorkoutFlow`, `CaffeineFlow`, `TrainingHubFlow`, `VolumeTrendsFlow`, `WorkoutCalendarFlow`, onboarding, smoke
- **Extensions**: `WatchSyncModels`, `WidgetModels` (Foundation-only, multi-target)

## Product rules

- Corrupted store → quarantine, not delete (`trackerApp`)
- Apply Adjustments never edits logged sets
- Watch context: `PhoneConnectivityManager.collectWatchContext()` / `pushWatchContext()`

## Strava (optional)

`Config/Secrets.xcconfig` with `STRAVA_CLIENT_ID` / `STRAVA_CLIENT_SECRET` (gitignored).
