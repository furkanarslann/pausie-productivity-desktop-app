import SwiftUI

/// Figma segmented control: lavender-tint track, the selected segment is a raised `surface/window` pill.
struct SegmentedPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    var body: some View {
        HStack(spacing: Metrics.Segment.spacing) {
            ForEach(options, id: \.value) { option in
                segment(option.value, label: option.label)
            }
        }
        .padding(Metrics.Segment.trackPadding)
        .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color(.brandLavenderTint)))
        .fixedSize()
    }

    private func segment(_ value: Value, label: String) -> some View {
        let isSelected = value == selection
        let shadow = ShadowToken.segment
        return Button {
            selection = value
        } label: {
            Text(label)
                .typography(.menu)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(Color(isSelected ? .brandPrimary : .textSecondary))
                .padding(Metrics.Segment.padding)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Radius.segment)
                            .fill(Color(.surfaceWindow))
                            .shadow(color: Color.shadowInk.opacity(shadow.opacity), radius: shadow.blur / 2, x: 0, y: shadow.y)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: Radius.segment))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
