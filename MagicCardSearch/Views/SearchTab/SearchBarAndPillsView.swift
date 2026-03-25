import SwiftUI

struct SearchBarAndPillsView: View {
    @Binding var searchState: SearchState

    @State var showWarningsPopover: Bool = false
    @FocusState private var searchBarFocused: Bool
    private let maxPillRows: Int = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                WarningsPillView(
                    warnings: searchState.results?.value.latestValue?.warnings ?? [],
                    mode: .pill,
                    isExpanded: $showWarningsPopover
                )
                Spacer()
                if !searchState.filters.isEmpty {
                    Button(role: .destructive, action: searchState.clearAll) {
                        Text("Clear all")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                if !searchState.filters.isEmpty {
                    ReflowingFilterPillsView(
                        filters: searchState.filters,
                        maxRows: maxPillRows,
                        onEdit: onFilterEdit,
                        onRemove: onFilterRemove
                    )
                    .mask {
                        VStack(spacing: 0) {
                            Rectangle()
                            LinearGradient(
                                colors: [.black, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 20)
                        }
                    }

                    Divider()
                        .padding(.horizontal)
                }

                SearchBarView(searchState: $searchState, isFocused: $searchBarFocused)
            }
            .contentShape(Rectangle())
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func onFilterEdit(_ filter: FilterQuery<FilterTerm>) {
        if let index = searchState.filters.firstIndex(of: filter) {
            searchState.filters.remove(at: index)
        }
        searchState.searchText = filter.description
        searchState.desiredSearchSelection = .init(range: filter.suggestedEditingRange)
        searchBarFocused = true
    }

    private func onFilterRemove(_ filter: FilterQuery<FilterTerm>) {
        if let index = searchState.filters.firstIndex(of: filter) {
            searchState.filters.remove(at: index)
        }
        searchBarFocused = true
    }
}
