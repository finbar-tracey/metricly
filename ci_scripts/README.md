# CI — Xcode Cloud setup

This directory contains scripts that Xcode Cloud invokes at specific
points in the workflow. The workflow itself is configured in App Store
Connect (you can't check that part into git).

## One-time setup

In **App Store Connect → Apps → Metricly → Xcode Cloud**:

1. **Create a workflow** (typically: trigger on PR, run Tests action
   against the iOS simulator).
2. **Pick a test plan**: under the workflow's *Test* action, point at
   `tracker.xctestplan` at the repo root. (The plan is checked in next
   to the project — Xcode Cloud discovers it automatically once the
   workflow's *Test* action is set to "Use Test Plan".)
3. **Add environment variables** under Settings → Environment Variables:
   - `STRAVA_CLIENT_ID` (Value — visible in logs is fine)
   - `STRAVA_CLIENT_SECRET` (Secret — masked in logs)

   `ci_scripts/ci_post_clone.sh` materialises these into
   `Secrets.xcconfig` so the build links against real credentials. If
   either is missing the build still passes; the Strava connect flow
   just returns `.notConfigured` at runtime.

## What runs in CI

The test plan currently runs every test in the `trackerTests` bundle —
~59 tests across the engine, schema, intent, soreness, trust-cal, CSV,
and Strava-import test files. That's a few seconds per run and catches
the kind of regression a manual test sweep would miss.

## Local equivalents

```sh
# Build for iPhone simulator (matches CI)
xcodebuild -scheme tracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run the same test plan locally
xcodebuild test -scheme tracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -testPlan tracker
```

## Lifecycle scripts available

Xcode Cloud honors specific filenames in this directory:

| Filename                 | Runs when                                |
| ------------------------ | ---------------------------------------- |
| `ci_post_clone.sh`       | After `git clone` — populate secrets here |
| `ci_pre_xcodebuild.sh`   | Before each `xcodebuild` invocation      |
| `ci_post_xcodebuild.sh`  | After each `xcodebuild` invocation       |

Only `ci_post_clone.sh` exists today; add the others if you need them.
