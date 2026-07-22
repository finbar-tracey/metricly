import SwiftUI

// Brand tokens shared by the app and its extensions.
//
// These live outside `AppTheme` because the widget and watch targets can't see
// the app's view layer, and three private copies of the same RGB tuple is
// exactly how a brand drifts. `AppTheme` re-exports everything here, so app
// call sites are unchanged.

/// Colors that appear on more than one surface — app, widget, Live Activity.
enum MetriclyBrand {
    /// Bright orange for runs / cardio / active-workout accents.
    static let runOrange = Color(red: 1.0, green: 0.52, blue: 0.15)
    /// Strong red — the deep stop of the workout ramp, heart-rate accents.
    static let alarmRed = Color(red: 0.88, green: 0.22, blue: 0.10)

    /// The active-workout gradient. The Live Activity, the widget's workout
    /// surfaces and the in-app CTA all draw from this one ramp.
    static let workout: [Color] = [runOrange, alarmRed]
}

/// The dark, signal-glow palette introduced by the Home redesign
/// (design_handoff_app, direction C2), at its "calm pass" values.
///
/// Deep neutrals with a slight cool cast, chosen so the signal colors *glow*
/// against them rather than merely sit on them. Every surface sits one step
/// above the original handoff so the screen reads calmer and the accents carry
/// the contrast.
///
/// The handoff quotes each token as oklch with a hand-tuned sRGB equivalent;
/// these are the sRGB column, which is the one tuned to preserve the perceived
/// lightness on a P3 iPhone display. (A straight oklch→sRGB conversion lands
/// ~0.05 L darker and undoes the calm pass.)
///
/// Reach for `AppTheme.Dark` inside the app — it's a typealias for this.
enum MetriclyDark {

    // MARK: Surfaces

    /// App background. #1B1D23
    static let bg = Color(red: 0.106, green: 0.114, blue: 0.137)
    /// Edges and deep recesses. #17191F
    static let bgInset = Color(red: 0.090, green: 0.098, blue: 0.122)
    /// Card backgrounds. #262932
    static let surface = Color(red: 0.149, green: 0.161, blue: 0.196)
    /// Inset wells — the micro-signal row sits in one of these. #1F222A
    static let surfaceLo = Color(red: 0.122, green: 0.133, blue: 0.165)
    /// Elevated chips, ring tracks, rest-day tape cells. #2F323D
    static let surfaceHi = Color(red: 0.184, green: 0.196, blue: 0.239)

    /// Card borders and dividers. #464A55 @ 60%
    static let hairline = Color(red: 0.275, green: 0.290, blue: 0.333).opacity(0.6)
    /// Half-strength hairline for scanlines and interior rules. @ 30%
    static let hairlineSoft = Color(red: 0.275, green: 0.290, blue: 0.333).opacity(0.3)

    // MARK: Text scale

    /// Primary text. #F0F1F5
    static let text = Color(red: 0.941, green: 0.945, blue: 0.961)
    /// Secondary / supporting copy. #A4A8B3
    static let text2 = Color(red: 0.643, green: 0.659, blue: 0.702)
    /// Eyebrow labels. #6E7280
    static let text3 = Color(red: 0.431, green: 0.447, blue: 0.502)
    /// Axis labels, very low importance. #62656F
    static let text4 = Color(red: 0.384, green: 0.396, blue: 0.435)

    /// Near-black used for text *on* an accent fill (CTA labels). #0A0D10
    ///
    /// Deliberately not `.black`: the accents are bright enough that pure black
    /// reads as a hole punched in them.
    static let ink = Color(red: 0.039, green: 0.051, blue: 0.063)

    /// Rest-day cells in the effort tape — a surface, not a signal, so a blank
    /// day never competes with a trained one.
    static let tapeRest = surfaceHi

    // MARK: Signals
    //
    // Unchanged by the calm pass. Use these instead of `AppTheme.Signal.*`
    // anywhere the dark surfaces above are in play — the standard palette is
    // tuned for white cards and goes muddy on these neutrals.
    enum Signal {
        /// Hard / high readiness / positive. #5CDD9B
        static let recovery = Color(red: 0.361, green: 0.867, blue: 0.608)
        /// Overworked / negative. #F06054
        static let strain = Color(red: 0.941, green: 0.376, blue: 0.329)
        /// Moderate / warning. #F0C060
        static let caution = Color(red: 0.941, green: 0.753, blue: 0.376)
        /// Light / focus session. #A07CFA
        static let focus = Color(red: 0.627, green: 0.486, blue: 0.980)
        /// Cardio / sleep / informational. #74B0F5
        static let calm = Color(red: 0.455, green: 0.690, blue: 0.961)
    }

    // MARK: Radii
    //
    // A tighter scale than the app-wide `AppTheme.*Radius` tokens — the
    // redesign's cards are smaller and squarer.
    enum Radius {
        /// Hero banner.
        static let hero: CGFloat = 22
        /// Next-up card.
        static let card: CGFloat = 18
        /// Inset wells, signal row, CTAs.
        static let well: CGFloat = 12
        /// Eyebrow chips.
        static let chip: CGFloat = 8
        /// Effort-tape bar tops.
        static let bar: CGFloat = 3
    }
}

// MARK: - Glow

extension View {
    /// The soft drop-shadow "glow" that makes an accent read as emissive
    /// against the dark neutrals. Light mode should use depth (layered shadows)
    /// instead — glow on a white surface just looks like a smudge.
    func signalGlow(_ color: Color, radius: CGFloat = 8, opacity: Double = 0.55) -> some View {
        shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}
