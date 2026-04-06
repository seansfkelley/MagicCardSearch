import SwiftUI
import ScryfallKit

struct SpoilersSetSelectorView: View {
    let spoilingSets: [MTGSet]
    @Binding var selectedSetCode: SetCode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SetSelectorCapsule(
                    icon: Image("allSetsIcon").renderingMode(.template).resizable().aspectRatio(contentMode: .fit),
                    label: "All Sets",
                    sublabel: nil,
                    isSelected: selectedSetCode == allSetsSentinel
                ) {
                    selectedSetCode = allSetsSentinel
                }

                ForEach(spoilingSets, id: \.code) { set in
                    SetSelectorCapsule(
                        icon: SetIconView(setCode: SetCode(set.code), size: 32),
                        label: set.name,
                        sublabel: [
                            set.code.uppercased(),
                            set.releasedAtAsDate.map { $0.formatted(.dateTime.month(.abbreviated).day()) },
                        ].compactMap(\.self).joined(separator: " • "),
                        isSelected: selectedSetCode == SetCode(set.code)
                    ) {
                        selectedSetCode = SetCode(set.code)
                    }
                }
            }
        }
        .padding(6)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 30))
    }
}

private struct SetSelectorCapsule<Icon: View>: View {
    let icon: Icon
    let label: String
    let sublabel: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.caption.bold())
                    if let sublabel {
                        Text(sublabel)
                            .font(.caption2)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 4) // The text ends up real close to the edge otherwise.
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
