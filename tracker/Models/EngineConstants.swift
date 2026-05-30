import Foundation

/// Centralized tuning knobs for the recovery / today-plan / progression
/// engines. Every value here is a behavioural threshold that controls
/// what the user sees — not a structural constant. The point of having
/// them in one place is that when you tune one (say, "users on 6h sleep
/// shouldn't take a 20% readiness hit"), you don't grep across five
/// files to find every occurrence.
///
/// Each constant carries a comment on what it does and, where possible,
/// why the chosen value. Treat that as the spec; the engine code is the
/// implementation.
///
/// Not yet migrated: PersonalInsightsEngine has its own ~30 thresholds
/// (sample-size minimums, effect-size cutoffs, sleep/caffeine windows).
/// Centralising those is tracked separately to keep this diff bounded.
enum EngineConstants {

    // MARK: - Recovery engine

    enum Recovery {

        /// Base recovery hours per muscle group. Adjusted at runtime by
        /// volume, RPE, and health multipliers. Legs are slowest because
        /// they accumulate the most systemic damage; biceps/triceps are
        /// the fastest because they're small and recover quickly.
        static let baseRecoveryHours: [MuscleGroup: Double] = [
            .chest: 48, .back: 48, .shoulders: 48,
            .biceps: 36, .triceps: 36, .legs: 72,
            .core: 24, .cardio: 24, .other: 48
        ]

        /// How far back, relative to a muscle's base recovery, to look
        /// for sessions that still contribute to current fatigue. 2× the
        /// base means a 48h-recovery muscle considers anything in the
        /// last 96h — past that, residual fatigue is negligible.
        static let sessionLookbackMultiplier: Double = 2.0

        /// Trailing-average volume window (days). Used to normalize each
        /// session's volume against the user's recent baseline.
        static let trailingVolumeDays: Int = 28

        /// Minimum number of volume samples required to trust the
        /// trailing average. Below this, the engine falls back to a
        /// neutral 1.0× volume multiplier.
        static let trailingVolumeMinSamples: Int = 2

        // Volume multiplier formula: volumeFloor + volumeRange * min(ratio, volumeRatioCap)
        // Yields 0.7× recovery for a low-volume day, 1.9× for a 2×-baseline day.
        static let volumeFloor: Double = 0.7
        static let volumeRange: Double = 0.6
        static let volumeRatioCap: Double = 2.0

        // RPE multiplier formula: rpeFloor + rpeStep * avgRPE
        // RPE 6 → 1.00×, RPE 10 → 1.30× recovery.
        static let rpeFloor: Double = 0.55
        static let rpeStep: Double = 0.075

        /// Per-session compound-fatigue coefficient. Each prior session
        /// in the lookback window reduces composite freshness by
        /// (1 - residual * compoundCoefficient). 0.6 chosen empirically:
        /// strong enough that 3 back-to-back hard sessions visibly
        /// stack, gentle enough that one moderate session doesn't crush
        /// the score.
        static let compoundFatigueCoefficient: Double = 0.6

        // Health multipliers applied to recovery hours (>1 = slower, <1 = faster).
        // Symmetric thresholds: 15% below/above baseline triggers a step.
        static let hrvLowRatio: Double = 0.85
        static let hrvHighRatio: Double = 1.15
        static let hrvLowMultiplier: Double = 1.20
        static let hrvHighMultiplier: Double = 0.85

        static let sleepPoorHours: Double = 6.0
        static let sleepPoorMultiplier: Double = 1.15

        static let rhrModerateRatio: Double = 1.05
        static let rhrHighRatio: Double = 1.10
        static let rhrModerateMultiplier: Double = 1.07
        static let rhrHighMultiplier: Double = 1.15

        // Aggregate readiness score modifiers.
        /// HRV's contribution to aggregate score is bounded at ±20%.
        static let hrvAggregateWeight: Double = 0.20
        static let rhrAggregateModerateMultiplier: Double = 0.95
        static let rhrAggregateHighMultiplier: Double = 0.90
        static let sleepAggregatePoorMultiplier: Double = 0.80
        static let sleepGoodHours: Double = 7.5
        static let sleepAggregateGoodMultiplier: Double = 1.10

        // External (HealthKit) workout fatigue.
        /// Look-back window for non-app workouts that still count.
        static let externalLookbackHours: Double = 48
        /// Scale factor: ExternalWorkout.estimatedFatigueScore × this.
        static let externalFatigueScale: Double = 0.15
        /// Cap on freshness reduction from all external workouts combined.
        static let externalFatigueCap: Double = 0.30

        // Cardio session fatigue.
        /// Long runs can linger 3 days in the legs; we look back that far.
        static let cardioLookbackHours: Double = 72
        static let cardioDurationFullScoreSeconds: Double = 90 * 60   // 90 min
        static let cardioDistanceFullScoreMeters: Double = 20_000     // 20 km
        /// Systemic impact (non-leg muscles) is 45% of leg impact.
        static let cardioSystemicShare: Double = 0.45
        static let cardioImpactScale: Double = 0.18
        static let cardioLegImpactCap: Double = 0.60
        static let cardioSystemicImpactCap: Double = 0.30

        // Per-cardio-type intensity multipliers. Run = 1.0 baseline;
        // cycle = 0.65 (lower-impact, sustained); walk = 0.25 (minimal
        // mechanical stress).
        static let cardioRunIntensity: Double = 1.00
        static let cardioCycleIntensity: Double = 0.65
        static let cardioWalkIntensity: Double = 0.25

        // Pace-zone multipliers for runs. Higher zone → faster pace →
        // more fatigue.
        static let cardioPaceSpeed: Double = 1.40
        static let cardioPaceThreshold: Double = 1.25
        static let cardioPaceTempo: Double = 1.12
        static let cardioPaceAerobic: Double = 1.00
        static let cardioPaceEasy: Double = 0.85
        static let cardioPaceRecovery: Double = 0.70

        // Magnitude scaling: composite (type × work × pace) × this = final.
        static let cardioMagnitudeScale: Double = 2.0

        // User-reported soreness (third intensity signal alongside
        // training volume and RPE). Levels 0–4 from SorenessEntry.
        /// Reports older than this are no longer considered.
        static let sorenessLookbackHours: Double = 48
        /// Each level beyond 0 multiplies freshness by (1 - step). So
        /// level 1 = 0.925× freshness, level 4 = 0.70× freshness.
        static let sorenessLevelStep: Double = 0.075

        // Display thresholds (color/label cutoffs on freshness 0–1).
        static let freshnessReadyThreshold: Double = 0.8
        static let freshnessAlmostThreshold: Double = 0.5
        static let freshnessRecoveringThreshold: Double = 0.25

        /// Freshness threshold above which a muscle is "ready to train"
        /// in `suggestWorkoutType`. Tighter than the display threshold
        /// because we want only well-recovered groups driving the
        /// recommendation.
        static let suggestReadyThreshold: Double = 0.7
        /// Minimum ready muscle count to recommend a Full Body session
        /// when the push/pull/legs combos aren't satisfied.
        static let suggestFullBodyMinReady: Int = 3
    }

    // MARK: - Today plan engine

    enum TodayPlan {

        // Intensity decision thresholds on readiness score (0–1).
        // < restThreshold → rest day. >= hardThreshold → hard. Between
        // light and hard → light or moderate, see below.
        static let restThreshold: Double = 0.30
        static let lightThreshold: Double = 0.55
        static let hardThreshold: Double = 0.85

        // Sleep callout thresholds (hours).
        static let sleepShortHours: Double = 6.0
        static let sleepGoodHours: Double = 7.5

        /// HRV / RHR baseline deviation needed to call out (±10% / +5 bpm).
        static let hrvCalloutPct: Double = 0.10
        static let rhrCalloutDeltaBpm: Double = 5.0

        /// Freshness below this flags a muscle as fatigued in `goEasyOn`.
        static let fatiguedFreshnessThreshold: Double = 0.4

        // "Neglected groups" heuristic.
        static let neglectedLookbackDays: Int = 7
        /// Don't surface "you haven't trained X" until the user has
        /// logged a couple of recent sessions — otherwise it fires on
        /// their first day and feels nagging.
        static let neglectedMinRecentSessions: Int = 2
        /// Working sets needed within the lookback window for a group to
        /// count as "trained" — anything below this still flags as
        /// neglected. Four sets ≈ one real exercise session; one token
        /// set on a Saturday shouldn't satisfy the chest's weekly need.
        static let neglectedMinWorkingSets: Int = 4

        // "Overworked group" heuristic.
        static let overworkedLookbackDays: Int = 5
        /// Trained on this many distinct days within the lookback →
        /// flagged as overworked. Three days out of five is "every other
        /// session" — high enough to warrant a suggestion to mix it up.
        static let overworkedDayThreshold: Int = 3

        // Confidence thresholds.
        /// At least this many populated health signals (HRV / RHR /
        /// sleep) to reach high confidence on the recovery axis.
        static let confidenceHealthSignalsForHigh: Int = 2
        /// At least this many recent workouts to reach high confidence
        /// on the training-depth axis. ~1 week of training.
        static let confidenceWorkoutsForHigh: Int = 7

        /// Cap on reasons shown on the plan card to keep it scannable.
        static let maxReasonsShown: Int = 3

        // Trust-calibration thresholds (PlanComplianceEvent driven).
        /// Compliance rate below this floor demotes the plan's confidence
        /// by one bucket (high→medium, medium→low). Even a well-
        /// instrumented user can't be predicted with "high confidence"
        /// if they reliably ignore what the engine suggests.
        static let complianceConfidenceFloor: Double = 0.6
        /// Compliance rate below this floor surfaces a gentle "you've
        /// ignored this before" reason on the plan card. Stricter than
        /// the confidence floor so the wording only fires when the
        /// pattern is meaningful.
        static let complianceCalloutFloor: Double = 0.5
        /// Need at least this many recent events before either
        /// downgrade fires. A handful of days isn't enough signal.
        static let complianceCalloutMinSamples: Int = 4
        /// How far back to read compliance events for the trust-cal
        /// adjustment. Matches the backfill's lookback window.
        static let complianceLookbackDays: Int = 7

        // MARK: User feedback ("how did that feel?")
        //
        // Sibling to the compliance constants — this gates the reason
        // line that surfaces when the user has tapped a majority feel
        // on several recent finishes. Threshold is intentionally lower
        // than compliance's `4` because reported feedback is higher-
        // quality signal per data point (we asked directly), so 3
        // events with a clear majority is enough.

        /// Minimum number of recent `WorkoutFeedbackEvent` rows before
        /// the feedback reason line is allowed to fire. Below this we
        /// don't have enough data to call a "majority."
        static let feedbackCalloutMinSamples: Int = 3
    }

    // MARK: - Compliance backfill
    //
    // The compliance backfill is the inverse of the today-plan engine:
    // it observes what the user actually did and classifies it into the
    // same `rest / light / moderate / hard` buckets the engine recommends
    // out of. These thresholds are intentionally forgiving — we'd rather
    // under-flag non-compliance than scold a user for a 20-min light
    // session on a moderate day — but they MUST stay paired with the
    // forward direction. If `TodayPlan` retunes "hard" upward (more sets
    // expected), the backfill's "what counts as hard" needs to move
    // alongside it. Living here makes that pairing visible.

    enum Compliance {

        /// At-or-above this many working sets in a day → classified as hard.
        static let hardSetCount: Int = 20

        /// At-or-above this much total volume (sets × reps × weight, kg)
        /// in a day → classified as hard. Even if set count is moderate,
        /// 2000 kg of work is a real heavy session.
        static let hardVolumeKg: Double = 2000

        /// At-or-above this many cardio minutes in a day → classified as
        /// hard. Catches the long-run / long-ride day where lifts are absent.
        static let hardCardioMinutes: Double = 60

        /// At-or-below this many working sets AND at-or-below
        /// `lightCardioMinutes` → classified as light. Both conditions
        /// must hold; a small-sets day with a long ride is still moderate.
        static let lightSetCount: Int = 8

        /// At-or-below this many cardio minutes (paired with the set
        /// count above) → classified as light.
        static let lightCardioMinutes: Double = 30
    }

    // MARK: - Personal insights engine
    //
    // Insight-engine knobs. Per-insight strength buckets and weight
    // formulas stay inline at their call sites (they're locally tuned
    // signal/noise tradeoffs) — only the cross-cutting ones live here.

    enum PersonalInsights {

        // Lookback windows
        /// Wide window for most rich insights (sleep × lift, rest × perf,
        /// body weight × strength, time of day).
        static let wideLookbackDays: Int = 90
        /// Narrower window for next-day HRV correlations where the user
        /// realistically only has a couple of months of paired data.
        static let mediumLookbackDays: Int = 60
        /// 4-week buckets used by the consistency trend.
        static let trendWindowDays: Int = 28
        /// Combined 8-week window for the trend's prior-period baseline.
        static let trendWindowPriorDays: Int = 56

        // Sample-size minimums
        /// Across most pattern-based insights, ≥4 paired samples is the
        /// floor below which any percentage difference is just noise.
        static let minPairedSamples: Int = 4
        /// Floor for the "top exercise" detection — fewer than this and
        /// we can't trust which lift is the user's regular compound.
        static let minTopExerciseHits: Int = 6
        /// Floor for the time-of-day insight where buckets fragment the
        /// per-exercise count three ways; we need a bit more data.
        static let minTopExerciseHitsTimeOfDay: Int = 8

        // Effect-size thresholds (percent unless noted)
        /// Default "is this signal real?" floor for percentage deltas.
        /// Below ~4% the variability of human strength on a given day
        /// dwarfs any pattern.
        static let minEffectPct: Double = 4
        /// HRV is intrinsically noisier than top-set weight, so we
        /// demand a slightly larger effect before surfacing.
        static let minHRVEffectPct: Double = 5
        /// Trend swings smaller than this are too small to be worth
        /// telling the user about.
        static let minTrendPct: Double = 15
        /// Sleep-delta threshold for the late-caffeine insight (minutes).
        static let minSleepDeltaMinutes: Double = 15

        // Domain thresholds
        /// Hour-of-day cutoff for "late" caffeine (24h clock). Anything
        /// from this hour onward counts as late.
        static let lateCaffeineHour: Int = 15
        /// Minimum distance to count as a "long" run for the leg-day
        /// recovery insight. Tuned for recreational runners; ultra-
        /// runners may want a higher floor.
        static let longRunMeters: Double = 8_000
        /// Maximum distance to count as a "short" run (and lower bound
        /// excludes warm-up walks).
        static let shortRunUpperMeters: Double = 5_000
        static let shortRunLowerMeters: Double = 1_000
        /// Maximum gap allowed between a workout and the nearest body-
        /// weight reading for the BW × strength insight.
        static let bodyWeightProximityDays: Int = 7
        /// Minimum half-day gap between long and short runs' "next leg
        /// session" averages before we surface the insight.
        static let minLongRunDaysGap: Double = 0.5

        // Sleep buckets (hours)
        static let goodSleepHours: Double = 7
        static let shortSleepHours: Double = 6
    }

    // MARK: - Progression advisor

    enum Progression {

        // Per-muscle-group default weight increments (kg).
        static let legsIncrementKg: Double = 5.0
        static let defaultIncrementKg: Double = 2.5

        // RPE-based recommendation thresholds (averaged across last 2 sessions).
        /// ≤ this → "ready to increase" (still has headroom).
        static let rpeIncreaseThreshold: Double = 7.5
        /// Between increase and deload → "hold steady".
        static let rpeDeloadThreshold: Double = 9.0

        // Sustained-decline detection.
        /// Number of consecutive declining sessions before we recommend
        /// a deload from weight/rep trend alone (without RPE).
        static let sustainedDeclineSessions: Int = 3

        // Confidence floor for various recommendation paths.
        static let confidenceHold: Double = 0.4
        static let confidenceMinorDipHold: Double = 0.35
        static let confidenceMixedSignals: Double = 0.3
        static let confidenceWeightUp: Double = 0.8
        static let confidenceRepsUp: Double = 0.65
        static let confidenceDeload: Double = 0.7

        /// Epley 1RM divisor: estimated 1RM = w × (1 + r / divisor).
        /// 30 is the standard Epley formula.
        static let epleyDivisor: Double = 30.0
    }
}
