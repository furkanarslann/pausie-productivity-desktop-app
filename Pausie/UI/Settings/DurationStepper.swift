import SwiftUI

/// Figma stepper: one bordered pill, − / "{n} min" / +.
struct DurationStepper: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let step: Int
    let accessibilityLabel: String

    var body: some View {
        HStack(spacing: 0) {
            stepButton(Icon.minus, enabled: minutes > range.lowerBound) {
                minutes = Self.decrement(minutes, step: step, range: range)
            }
            Text(L10n.t(.settingsDurationValue, ["minutes": TimeFormat.number(minutes)]))
                .typography(.bodyEmphasis)
                .foregroundStyle(Color(.textPrimary))
                .monospacedDigit()
                .frame(width: Metrics.Stepper.valueWidth)
            stepButton(Icon.plus, enabled: minutes < range.upperBound) {
                minutes = Self.increment(minutes, step: step, range: range)
            }
        }
        .frame(height: Metrics.Stepper.height)
        .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color(.surfaceWindow)))
        .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(Color(.borderSubtle), lineWidth: BorderWidth.hairline))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(L10n.t(.settingsDurationValue, ["minutes": TimeFormat.number(minutes)]))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: minutes = Self.increment(minutes, step: step, range: range)
            case .decrement: minutes = Self.decrement(minutes, step: step, range: range)
            @unknown default: break
            }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: Metrics.Stepper.iconSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(.brandPrimary))
                .frame(width: Metrics.Stepper.buttonSize, height: Metrics.Stepper.buttonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : OpacityToken.disabled)
    }

    /// Moves to the next multiple of `step`, clamped to the range.
    nonisolated static func increment(_ value: Int, step: Int, range: ClosedRange<Int>) -> Int {
        min(range.upperBound, (value / step + 1) * step)
    }

    /// Moves to the previous multiple of `step`, clamped to the range (so 10 → 6 for work, the minimum).
    nonisolated static func decrement(_ value: Int, step: Int, range: ClosedRange<Int>) -> Int {
        max(range.lowerBound, ((value - 1) / step) * step)
    }
}
