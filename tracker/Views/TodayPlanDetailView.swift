import SwiftUI

/// The pre-session plan view, reached by tapping the hero or Next-Up card on
/// Home. Its whole job is the adaptive reasoning: *why* this plan, *why* these
/// weights, *what's* flagged — before a single set is logged.
///
/// Restyled to the v2 dark language (design_handoff_app, `screen-detail.jsx`).
/// The handoff's file map calls this `WorkoutDetailView`, but that name already
/// belongs to the logged-workout screen, and this is the screen actually wired
/// to the Next-Up tap — so the restyle lands here, keeping the `.planDetail`
/// route intact.
struct TodayPlanDetailView: View {
    let plan: TodayPlan
    let recovery: RecoveryResult
    let health: HealthSignals
    let data: PlanDetailData
    /// Start the session and pop back to Home. nil on a rest day, where there's
    /// no session to start.
    var onStart: (() -> Void)?
    var onBack: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    private var accent: Color { AppTheme.Dark.accent(for: plan.intensity) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                whyThisPlan
                if !data.muscleLoad.isEmpty {
                    muscleLoad
                }
                if !data.lifts.isEmpty {
                    theLifts
                }
            }
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) { if onStart != nil { cta } }
        .background(AppTheme.Dark.bg.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        // A focused pre-session screen: the tab bar steps aside so the back
        // button and the Start CTA are the only two ways out, matching the
        // handoff's full-bleed detail and freeing the bottom for the CTA.
        .hidesMetriclyTabBar()
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(AppTheme.Dark.bg, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onBack()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("TODAY")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                    }
                    .foregroundStyle(AppTheme.Dark.text3)
                }
                .accessibilityLabel("Back to today")
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                pill
                Spacer(minLength: 8)
                Text(data.meta)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.Dark.text3)
            }
            HStack(spacing: 6) {
                Text(data.titleMain)
                    .foregroundStyle(AppTheme.Dark.text)
                if let suffix = data.titleSuffix {
                    Text(suffix)
                        .foregroundStyle(AppTheme.Dark.text3)
                }
            }
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .tracking(-1.4)
            .lineSpacing(0)
            .minimumScaleFactor(0.7)
            .lineLimit(2)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    private var pill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
                .signalGlow(accent, radius: 4)
            Text(data.pillText)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(accent.opacity(0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(accent.opacity(0.33), lineWidth: 1))
        .accessibilityLabel(data.pillAccessibilityLabel)
    }

    // MARK: - Why this plan

    private var whyThisPlan: some View {
        section(title: "WHY THIS PLAN", right: "RECOVERY ENGINE") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(data.reasons.enumerated()), id: \.offset) { _, reason in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(accent)
                            .frame(width: 5, height: 5)
                            .signalGlow(accent, radius: 6)
                            .padding(.top, 6)
                        Text(reason)
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.Dark.text2)
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 5)
                }
                if let flag = data.flag {
                    Rectangle()
                        .fill(AppTheme.Dark.hairlineSoft)
                        .frame(height: 0.5)
                        .padding(.vertical, 9)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.Dark.Signal.caution)
                            .frame(width: 4, height: 4)
                        Text(flag)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Dark.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .darkCard(radius: 16, border: accent.opacity(0.25))
        }
    }

    // MARK: - Muscle load

    private var muscleLoad: some View {
        section(title: "MUSCLE LOAD · 7 DAY", right: data.muscleLoadCallout) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                alignment: .leading,
                spacing: 11
            ) {
                ForEach(Array(data.muscleLoad.enumerated()), id: \.element.id) { index, row in
                    muscleLoadRow(row, index: index)
                }
            }
        }
    }

    private func muscleLoadRow(_ row: PlanDetailData.MuscleLoad, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(row.name.uppercased())
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.Dark.text2)
                Spacer()
                Text("\(row.load)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(row.tone)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.Dark.surfaceHi)
                    Capsule()
                        .fill(row.tone)
                        .frame(width: max(4, geo.size.width * (Double(row.load) / 100)))
                        .signalGlow(row.tone, radius: 4, opacity: 0.4)
                        .growIn(
                            axis: .horizontal,
                            animation: .snappy(duration: 0.9),
                            delay: Double(index) * 0.08
                        )
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name) \(row.load) percent load")
    }

    // MARK: - The lifts

    private var theLifts: some View {
        section(title: "THE LIFTS", right: nil) {
            VStack(spacing: 0) {
                ForEach(Array(data.lifts.enumerated()), id: \.element.id) { index, lift in
                    liftRow(lift, index: index, isLast: index == data.lifts.count - 1)
                }
            }
            .darkCard(radius: 16)
        }
    }

    private func liftRow(_ lift: PlanDetailData.Lift, index: Int, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.Dark.text4)
                .frame(width: 20, alignment: .leading)
            Text(lift.name)
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(AppTheme.Dark.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 1) {
                Text(lift.load)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.Dark.text)
                Text(lift.sets)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.Dark.text3)
            }
            if let hint = lift.hint {
                Text(hint.text.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(hint.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 62, alignment: .trailing)
            } else {
                Color.clear.frame(width: 62, height: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(AppTheme.Dark.hairlineSoft)
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(lift.name), \(lift.load), \(lift.sets)\(lift.hint.map { ". \($0.text)" } ?? "")"
        )
    }

    // MARK: - CTA

    private var cta: some View {
        Button {
            onStart?()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(data.ctaTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .tracking(-0.2)
                    Text(data.ctaSubline)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.Dark.ink.opacity(0.73))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(AppTheme.Dark.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .signalGlow(accent, radius: 16, opacity: 0.4)
        }
        .buttonStyle(.pressableCard)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Section scaffold

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        right: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.Dark.text3)
                Spacer()
                if let right {
                    Text(right)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.Dark.text4)
                }
            }
            content()
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
    }
}
