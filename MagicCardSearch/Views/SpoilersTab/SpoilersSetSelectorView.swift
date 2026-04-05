import SwiftUI
import ScryfallKit

struct SpoilersSetSelectorView: View {
    let spoilingSets: [MTGSet]
    @Binding var selectedSetCode: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SetSelectorCapsule(
                    icon: SetIconView(setCode: SetCode("common"), size: 16),
                    label: "All Sets",
                    date: nil,
                    isSelected: selectedSetCode.isEmpty
                ) {
                    selectedSetCode = ""
                }

                ForEach(spoilingSets, id: \.code) { set in
                    SetSelectorCapsule(
                        icon: SetIconView(setCode: SetCode(set.code), size: 16),
                        label: set.code.uppercased(),
                        date: set.releasedAtAsDate,
                        isSelected: selectedSetCode == set.code
                    ) {
                        selectedSetCode = set.code
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

private struct SetSelectorCapsule<Icon: View>: View {
    let icon: Icon
    let label: String
    let date: Date?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.caption.bold())
                    if let date {
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption2)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            if isSelected {
                Capsule().fill(Color.accentColor)
            }
        }
        .overlay {
            if !isSelected {
                Capsule().stroke(Color.secondary.opacity(0.4), lineWidth: 1)
            }
        }
    }
}
