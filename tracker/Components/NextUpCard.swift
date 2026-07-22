import SwiftUI

/// The session on deck: what it is, what's in it, and one button to start.
///
/// Tapping the card opens the plan in detail; tapping the CTA starts the
/// session. The eyebrow is where a swap gets explained ("SWAPPED IN · WAS:
/// PUSH DAY") — the user should never find out from the exercise list that the
/// plan changed under them.
struct NextUpCard: View {
    struct Exercise: Identifiable {
        let id = UUID()
        let name: String
        /// Set/rep label, e.g. "4 × 5".
        let sets: String
        /// Set count, shown zero-padded in the left gutter.
        let setCount: Int
        let hint: Hint?

        /// A one-word read on how to approach the lift, from the progression
        /// advisor. Carries its own tone so the row doesn't have to guess from
        /// the wording.
        struct Hint {
            let text: String
            let tone: Tone

            enum Tone { case push, ease, neutral }

            var color: Color {
                switch tone {
                case .push:    return AppTheme.Dark.Signal.recovery
                case .ease:    return AppTheme.Dark.Signal.caution
                case .neutral: return AppTheme.Dark.text3
                }
            }
        }
    }

    /// Eyebrow label — "NEXT UP · 07:30 PLANNED", or the swap explanation.
    let eyebrow: String
    /// Right-hand meta, e.g. "6 LIFTS · ~58 MIN".
    let meta: String
    let workoutName: String
    let exercises: [Exercise]
    let accent: Color
    /// CTA label, e.g. "Start Push Day".
    let ctaTitle: String
    var onOpenDetail: () -> Void = {}
    let onStart: () -> Void

    /// Rows beyond this collapse into a "+ N MORE" line — the card is a
    /// preview, not the session.
    private let visibleRows = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpenDetail) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Text(workoutName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .tracking(-0.4)
                        .foregroundStyle(AppTheme.Dark.text)
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                    rows
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the full session")

            cta
        }
        .darkCard()
    }

    private var header: some View {
        HStack {
            Text(eyebrow)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(AppTheme.Dark.text3)
            Spacer(minLength: 8)
            Text(meta)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(AppTheme.Dark.text3)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(exercises.prefix(visibleRows)) { row($0) }
            if exercises.count > visibleRows {
                Text("+ \(exercises.count - visibleRows) MORE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.Dark.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 6)
    }

    private func row(_ exercise: Exercise) -> some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", exercise.setCount))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(AppTheme.Dark.text4)
                .frame(width: 22, alignment: .leading)
            Text(exercise.name)
                .font(.system(size: 13.5, weight: .semibold))
                .tracking(-0.1)
                .foregroundStyle(AppTheme.Dark.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(exercise.sets)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.Dark.text2)
                .frame(width: 50, alignment: .trailing)
            if let hint = exercise.hint {
                Text(hint.text.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(hint.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 90, alignment: .trailing)
            } else {
                Color.clear.frame(width: 90, height: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(exercise.name), \(exercise.sets)\(exercise.hint.map { ". \($0.text)" } ?? "")"
        )
    }

    private var cta: some View {
        Button(action: onStart) {
            HStack {
                Text(ctaTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(-0.2)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(AppTheme.Dark.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(accent, in: RoundedRectangle(cornerRadius: AppTheme.Dark.Radius.well, style: .continuous))
            .signalGlow(accent, radius: 14, opacity: 0.35)
        }
        .buttonStyle(.pressableCard)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }
}

#Preview {
    NextUpCard(
        eyebrow: "NEXT UP · 07:30 PLANNED",
        meta: "6 LIFTS · ~58 MIN",
        workoutName: "Push Day · A",
        exercises: [
            .init(name: "Bench Press", sets: "4 × 5", setCount: 4,
                  hint: .init(text: "PR window", tone: .push)),
            .init(name: "Overhead Press", sets: "4 × 6", setCount: 4,
                  hint: .init(text: "Maintain", tone: .neutral)),
            .init(name: "Incline DB Press", sets: "3 × 10", setCount: 3,
                  hint: .init(text: "Volume", tone: .neutral)),
            .init(name: "Lateral Raise", sets: "3 × 12", setCount: 3,
                  hint: .init(text: "Tempo", tone: .neutral)),
            .init(name: "Tricep Pushdown", sets: "2 × 15", setCount: 2,
                  hint: .init(text: "Easy — go light", tone: .ease))
        ],
        accent: AppTheme.Dark.Signal.recovery,
        ctaTitle: "Start Push Day",
        onStart: {}
    )
    .padding(12)
    .background(AppTheme.Dark.bg)
    .preferredColorScheme(.dark)
}
