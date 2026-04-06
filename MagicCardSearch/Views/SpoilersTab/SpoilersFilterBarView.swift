import SwiftUI
import ScryfallKit

struct SpoilersFilterBarView: View {
    private let imageSize: CGFloat = 36

    @Binding var sortOrder: SpoilersSortOrder
    @Binding var selectedColors: Set<Card.Color>

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                Picker("Sort Order", selection: $sortOrder) {
                    ForEach(SpoilersSortOrder.allCases) { order in
                        Button(action: {}) {
                            Text(order.displayName)
                            Text(order.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(order)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageSize * 0.8, height: imageSize * 0.8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                ForEach(Card.Color.allCases, id: \.self) { color in
                    let isSelected = selectedColors.contains(color)
                    Button {
                        if isSelected {
                            selectedColors.remove(color)
                        } else {
                            selectedColors.insert(color)
                        }
                    } label: {
                        SymbolView(SymbolCode(color.rawValue), size: imageSize, showDropShadow: true)
                            .opacity(isSelected ? 1.0 : 0.35)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    selectedColors.removeAll()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.secondary)
                        .frame(width: imageSize * 0.8, height: imageSize * 0.8)
                }
                .disabled(selectedColors.isEmpty)
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }
}
