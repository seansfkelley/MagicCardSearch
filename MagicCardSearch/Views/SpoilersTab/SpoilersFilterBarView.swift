import SwiftUI

private let colorFilterOptions: [(letter: String, symbol: String)] = [
    ("W", "{W}"),
    ("U", "{U}"),
    ("B", "{B}"),
    ("R", "{R}"),
    ("G", "{G}"),
    ("C", "{C}"),
]

struct SpoilersFilterBarView: View {
    private let imageSize: CGFloat = 36

    @Binding var sortOrder: SpoilersSortOrder
    @Binding var selectedColors: Set<String>

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
                ForEach(colorFilterOptions, id: \.letter) { option in
                    let isSelected = selectedColors.contains(option.letter)
                    Button {
                        if isSelected {
                            selectedColors.remove(option.letter)
                        } else {
                            selectedColors.insert(option.letter)
                        }
                    } label: {
                        SymbolView(SymbolCode(option.symbol), size: imageSize)
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
        .padding(6)
        .animation(.default, value: selectedColors.isEmpty)
    }
}
