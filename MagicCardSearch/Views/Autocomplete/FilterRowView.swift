import SwiftUI

struct FilterRowView: View {
    @ScaledMetric private var iconWidth = AutocompleteConstants.defaultSuggestionIconWidth

    let suggestion: AutocompleteSuggestion
    let showImmediateSearchIcon: Bool
    let onTap: (FilterQuery<FilterTerm>) -> Void

    var body: some View {
        if case .filter(let match) = suggestion.content {
            Button {
                onTap(match.value)
            } label: {
                HStack(spacing: 12) {
                    suggestion.icon
                        .foregroundStyle(.secondary)
                        .font(.system(size: suggestion.iconFontSize))
                        .frame(width: iconWidth)

                    DebuggableScorableView(scorable: suggestion) {
                        Text(match.string.attributed(in: match.highlights) {
                            $0.font = .body.bold()
                            $0.foregroundColor = .primary
                        })
                        .foregroundStyle(match.highlights.isEmpty ? .primary : .secondary)
                        .truncationMode(.middle)
                        .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    if showImmediateSearchIcon {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            EmptyView()
        }
    }
}
