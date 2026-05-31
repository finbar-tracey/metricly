import SwiftUI
import SwiftData

// MARK: - Design tokens

enum AppTheme {
    // Radii
    static let heroRadius: CGFloat = 28
    static let cardRadius: CGFloat = 20
    /// Mini-card / tile-card tier — the smaller paired tiles on Home
    /// (plan & metrics row, health glance, quick links). Sits between
    /// `cardRadius` and `tileRadius`; was a hardcoded `16` in five files.
    static let miniCardRadius: CGFloat = 16
    static let tileRadius: CGFloat = 14
    static let chipRadius: CGFloat = 10

    // Spacing
    static let sectionSpacing: CGFloat = 28
    static let cardPadding: CGFloat = 18
    static let tilePadding: CGFloat = 14

    // Borders
    /// Hairline stroke on card / tile surfaces. Standardizes the
    /// 0.05–0.08 border-opacity spread that had drifted across the Home
    /// sections onto one value matching `appCard`.
    static let cardHairline = Color.white.opacity(0.08)

    /// Chart gridlines — subtle and tokenized. Replaces the heavier
    /// per-chart 0.12–0.15 gridline opacities that read as gray clutter
    /// behind the data.
    static let chartGrid = Color.secondary.opacity(0.09)

    // Signal palette — semantic colors per metric type.
    enum Signal {
        static let recovery     = Color(red: 0.20, green: 0.78, blue: 0.45)
        static let recoveryDeep = Color(red: 0.00, green: 0.52, blue: 0.42)
        /// Slightly darker than `recoveryDeep`; used in stat-strip gradients
        /// where the deepest stop needs to read against white text.
        static let recoveryShade = Color(red: 0.05, green: 0.55, blue: 0.42)
        static let strain       = Color(red: 0.95, green: 0.30, blue: 0.30)
        static let strainDeep   = Color(red: 0.78, green: 0.20, blue: 0.20)
        static let caution      = Color.orange
        static let cautionDeep  = Color(red: 0.85, green: 0.50, blue: 0.10)
        /// Borderline-but-not-bad signal — the middle stop on traffic-light
        /// ramps (recovery → warning → caution → strain). Uses the system
        /// yellow so it adapts to dark mode without a custom RGB tuple.
        static let warning      = Color.yellow
        static let focus        = Color(red: 0.55, green: 0.35, blue: 0.95)
        static let calm         = Color(red: 0.30, green: 0.55, blue: 0.95)
        /// Button accent for "Continue Workout" / progress CTAs — warmer
        /// than `cautionDeep`, brighter than `caution`.
        static let actionOrange = Color(red: 0.95, green: 0.45, blue: 0.20)
        /// Button accent for "Start Workout" / success CTAs — the deeper
        /// stop of the green gradient used across action buttons.
        static let actionGreen  = Color(red: 0.10, green: 0.72, blue: 0.40)
        /// Strong amber used in "this week" stat gradients.
        static let amber        = Color(red: 0.95, green: 0.62, blue: 0.10)
        /// Bright orange for runs / cardio accents (shared with widget).
        static let runOrange    = Color(red: 1.0, green: 0.52, blue: 0.15)
        /// Strong red used in heart-rate / strain gradients (shared with widget).
        static let alarmRed     = Color(red: 0.88, green: 0.22, blue: 0.10)
    }

    // Gradient palette — multi-stop palettes for hero surfaces.
    enum Gradients {
        static let recovery: [Color] = [
            Color(red: 0.20, green: 0.78, blue: 0.50),
            Color(red: 0.05, green: 0.55, blue: 0.55),
            Color(red: 0.00, green: 0.40, blue: 0.60)
        ]
        static let caution: [Color] = [
            Color(red: 0.98, green: 0.65, blue: 0.20),
            Color(red: 0.92, green: 0.45, blue: 0.20),
            Color(red: 0.78, green: 0.30, blue: 0.30)
        ]
        static let strain: [Color] = [
            Color(red: 0.95, green: 0.30, blue: 0.35),
            Color(red: 0.78, green: 0.20, blue: 0.30),
            Color(red: 0.55, green: 0.15, blue: 0.35)
        ]
        static let calm: [Color] = [
            Color(red: 0.30, green: 0.55, blue: 0.95),
            Color(red: 0.40, green: 0.40, blue: 0.92),
            Color(red: 0.55, green: 0.35, blue: 0.95)
        ]
        static let sleep: [Color] = [
            Color(red: 0.30, green: 0.20, blue: 0.55),
            Color(red: 0.42, green: 0.30, blue: 0.78),
            Color(red: 0.30, green: 0.40, blue: 0.85)
        ]
    }

    // Motion — named springs you reuse instead of inventing per-call.
    enum Motion {
        /// Quick, snappy press / tap reactions.
        static let snappy  = Animation.spring(response: 0.32, dampingFraction: 0.78)
        /// Default for value changes, transitions, layout shifts.
        static let smooth  = Animation.spring(response: 0.45, dampingFraction: 0.82)
        /// Playful for celebrations / highlights.
        static let bouncy  = Animation.spring(response: 0.55, dampingFraction: 0.62)
        /// Numeric tweens / chart entries.
        static let numeric = Animation.spring(response: 0.6, dampingFraction: 0.85)
    }
}

// MARK: - View modifiers

extension View {
    func appCard(padding: CGFloat = AppTheme.cardPadding) -> some View {
        self
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: 8)
    }

    func heroCard() -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.heroRadius, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 30, x: 0, y: 12)
    }
}

// MARK: - Shared components

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .tracking(0.7)
        }
        .padding(.leading, 2)
    }
}

struct GradientProgressBar: View {
    let value: Double
    let color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color.opacity(0.16))
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2)
                            .stroke(.white.opacity(0.20), lineWidth: 0.5)
                    )
                    .frame(width: geo.size.width * min(1, max(0, value)), height: height)
                    .shadow(color: color.opacity(0.45), radius: 4, x: 0, y: 2)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: value)
            }
        }
        .frame(height: height)
    }
}

// MARK: - HeroStatCol
// Replaces the ~14 private heroStatCol / heroStatColumn copies spread across views.
// Used inside gradient hero cards; always white text.

struct HeroStatCol: View {
    let value: String
    let label: String
    var icon:  String? = nil

    var body: some View {
        VStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - CapsuleSegmentPicker
// Replaces the ~6 identical animated capsule pickers in detail views.

struct CapsuleSegmentPicker<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    let options: [T]
    @Binding var selection: T
    var activeColor: Color = .accentColor

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selection = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selection == option ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selection == option
                                ? AnyShapeStyle(activeColor)
                                : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                            in: Capsule()
                        )
                        .shadow(color: selection == option ? activeColor.opacity(0.35) : .clear,
                                radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - ModelContext helpers

extension ModelContext {
    /// Saves the context and logs any error instead of silently swallowing it.
    func saveOrLog(file: String = #fileID, line: Int = #line) {
        do {
            try save()
        } catch {
            print("SwiftData save error [\(file):\(line)]: \(error)")
        }
    }
}

