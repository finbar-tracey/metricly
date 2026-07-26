import SwiftUI

/// A number that counts up from zero to `target` on appear. Drives an
/// `AnimatableModifier` whose `animatableData` is the value, so SwiftUI rebuilds
/// the text at each interpolated step rather than snapping start→end.
///
/// Reduce Motion shows the final value at once — the number is information, and
/// a stat that never arrives is worse than one that doesn't animate.
///
/// Font and color come from the environment, so style the `CountUpNumber` itself
/// (`.font(...)`, `.foregroundStyle(...)`) and the inner text inherits it.
struct CountUpNumber: View {
    let target: Double
    let decimals: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        Text(verbatim: "")
            .modifier(CountingText(value: shown ? target : 0, decimals: decimals))
            .onAppear {
                guard !reduceMotion else { shown = true; return }
                withAnimation(.easeOut(duration: 0.8)) { shown = true }
            }
    }
}

private struct CountingText: AnimatableModifier {
    var value: Double
    let decimals: Int

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    func body(content: Content) -> some View {
        Text(value, format: .number.precision(.fractionLength(decimals)))
    }
}
