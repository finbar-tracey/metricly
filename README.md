# Metricly

An adaptive iOS strength & cardio tracker that reads your recovery and adjusts what you train today.

![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![Platform](https://img.shields.io/badge/Platform-iOS_26-blue)
![watchOS](https://img.shields.io/badge/watchOS-11.6+-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## What makes it different

Most gym trackers are spreadsheets in disguise — you type, they store. Metricly closes the loop:

- **Adaptive plan engine.** `TodayPlanEngine` reads recovery, sleep, HRV, resting HR, recent volume, and per-muscle-group fatigue, then surfaces a recommendation for today (rest / light / moderate / hard) with a confidence rating that's only "high" when both health signals *and* training history are populated.
- **Apply Adjustments.** When the plan suggests trimming volume or skipping an overworked group, one tap edits the actual workout — safely. Logged sets are never touched.
- **Honest first-run UX.** With no history and no health data, the engine refuses to fake a high-confidence recommendation. You get a "log your first workout" nudge instead of a robotic call.
- **Watch is a peer, not a remote.** The watch app runs its own `HKWorkoutSession`, computes a true session-average heart rate via `HKLiveWorkoutBuilder.statistics`, and pushes its own context — the iPhone observes and merges.
- **Built for years of data.** A corrupted SwiftData store gets quarantined (renamed with a timestamp) on launch, never silently deleted.

## Features

**Strength**
- Workouts with exercises, sets, reps, weight, RPE, warm-ups, supersets, reordering
- Reusable templates and a weekly training schedule
- Quick-log from last session; weight auto-fills with increment buttons
- Personal record detection with celebration banner
- Rest timer with background notifications and audio alert
- Per-exercise progression charts and 1RM tracking

**Cardio**
- Live HR-tracked cardio sessions (run, bike, row, hike, walk, etc.)
- Auto-detected personal bests across distance/pace/duration buckets
- Cardio goals, history, and shareable session cards
- Strava push: per-session retroactive upload + auto-share toggle

**Recovery & Coaching**
- Readiness score combining training load, RPE, HRV, resting HR, and sleep
- Per-muscle-group fatigue tracking with multi-session accumulation
- Today's adaptive plan with reasons, adjustments, and confidence
- Progression advisor (load/rep recommendations grounded in recent sessions)
- Per-exercise "go easy on this group" hints inside the live workout

**Apple Watch**
- Standalone watch app (gym + cardio) with live HR, set logging, and rest timer
- True session-averaged heart rate (not just the latest sample)
- Complications surfacing streak + active workout
- Two-way sync via `WCSession` — single source of truth for the watch context

**Widgets & Siri**
- Lock-screen and home-screen widgets (streak, today's plan, recovery)
- Live Activity during a workout
- Siri shortcuts: start workout, today's plan, streak, stats, log weight, log water — the today-plan intent speaks the adaptive recommendation, not the static schedule

**Health**
- HealthKit sync for HRV, resting HR, steps, sleep
- Body weight, body measurements, body-fat estimate, progress photos
- Water, caffeine, and creatine logging with daily targets

**Reports & Analytics**
- Workout streak calendar, monthly training calendar
- Weekly and monthly recap reports
- Volume trends, muscle-group balance, personal insights engine
- Workout comparison (side-by-side sessions)
- Achievements (streak, volume, PR milestones)

**Data**
- CSV export and import
- iCloud sync via CloudKit (automatic, no account)
- Corrupted-store quarantine on launch (no silent data loss)
- Workout share cards (image export)

## Project layout

```
tracker/                 # iPhone app target
├── Models/              # @Model types + analytics engines
│   ├── RecoveryEngine        # readiness score + per-muscle fatigue
│   ├── TodayPlanEngine       # adaptive intensity / recommendation
│   ├── TodayPlanApply        # "Apply Adjustments" preview + commit
│   ├── ProgressionAdvisor    # load/rep recommendations
│   ├── SuggestedSetEngine    # next-set hints inside the workout
│   └── PersonalInsightsEngine
├── Views/               # SwiftUI screens (home, gym, cardio, health, settings…)
├── Components/          # Reusable view atoms (cards, share sheet, layout)
└── Helpers/             # CSV import/export, quick-start, etc.

Services/                # Cross-target services (shared with watch/widgets)
├── MetriclySchema       # Single source of truth for the SwiftData schema
├── PhoneConnectivityManager  # WCSession bridge + collectWatchContext()
├── HealthKitManager
├── StravaService / StravaTokenStore
├── WidgetDataWriter     # App Group bridge for widgets
├── CardioTracker
├── AppShortcuts         # App Intents (Siri)
└── ReminderManager

MetriclyWatch/           # watchOS app target
MetriclyWatchComplications/
MetriclyWidgets/         # WidgetKit extension + Live Activity
trackerTests/            # XCTest suite (engines + apply logic)
```

## Tech stack

- **SwiftUI** — declarative UI across iPhone + Watch
- **SwiftData** + CloudKit — `@Model`, `@Query`, `@Relationship`; container hardened against store corruption
- **HealthKit** — HRV, resting HR, sleep, live workout HR via `HKLiveWorkoutBuilder`
- **WatchConnectivity** — phone↔watch context sharing
- **App Intents** — Siri shortcuts (adaptive today's plan, streak, stats, water, weight)
- **WidgetKit** + ActivityKit — home/lock widgets and Live Activities
- **Swift Charts** — volume, progression, body weight, health charts
- **UserNotifications** — rest timer alerts, workout reminders

## Requirements

- iOS 26.0+ (app + widget extension)
- watchOS 11.6+ (watch app + complications)
- Xcode 16+
- Swift 5

## Getting started

1. Clone the repo
2. Open `tracker.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities for each target
4. (Optional, for Strava) Register an app at developers.strava.com, then
   create `Config/Secrets.xcconfig` with:
   ```
   STRAVA_CLIENT_ID = your_id
   STRAVA_CLIENT_SECRET = your_secret
   ```
   The file is gitignored; `ci_scripts/ci_post_clone.sh` materialises
   the same values from env vars in CI. If either is missing the build
   still passes — Strava just returns `.notConfigured` at runtime.
   Callback URL must be `metricly://localhost/strava-callback`.
5. Build and run on a device or simulator

## Tests

The full test plan runs via `tracker.xctestplan` and is the same plan
Xcode Cloud executes on every PR:

```sh
xcodebuild test -scheme tracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -testPlan tracker
```

The suite covers the recovery engine (including soreness signals), the
adaptive today-plan engine, today-plan apply logic, plan compliance
backfill (boundary thresholds + idempotency), trust calibration, the
schema migration plan (V1→V2→V3 round-trip on a real SQLite file),
progression advisor, streak math, widget data writer, watch sync
payloads + message-key contracts, Strava error mapping and import
service, CSV round-trip, and unit/formatting helpers — **500+** test
methods across **36** XCTest files (see `trackerTests/`).

## License

MIT License — see [LICENSE](LICENSE) for details.
