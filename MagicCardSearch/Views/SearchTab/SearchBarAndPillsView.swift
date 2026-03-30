import SwiftUI

struct SearchBarAndPillsView: View {
    var editingState: SearchEditingState
    let warnings: [String]
    let onSearch: () -> Void

    @State var showWarningsPopover: Bool = false
    @FocusState private var searchBarFocused: Bool
    private let maxPillRows: Int = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                WarningsPillView(
                    warnings: warnings,
                    mode: .pill,
                    isExpanded: $showWarningsPopover
                )
                Spacer()
                if !editingState.filters.isEmpty {
                    Button(role: .destructive) {
                        editingState.searchText = ""
                        editingState.desiredSearchSelection = nil
                        editingState.filters = []
                    } label: {
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
                if !editingState.filters.isEmpty {
                    ReflowingFilterPillsView(
                        filters: editingState.filters,
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

                SearchBarView(editingState: editingState, onSearch: onSearch, isFocused: $searchBarFocused)
            }
            .contentShape(Rectangle())
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func onFilterEdit(_ filter: FilterQuery<FilterTerm>) {
        if let index = editingState.filters.firstIndex(of: filter) {
            editingState.filters.remove(at: index)
        }
        editingState.searchText = filter.description
        editingState.desiredSearchSelection = .init(range: filter.suggestedEditingRange)
        searchBarFocused = true
    }

    private func onFilterRemove(_ filter: FilterQuery<FilterTerm>) {
        if let index = editingState.filters.firstIndex(of: filter) {
            editingState.filters.remove(at: index)
        }
        searchBarFocused = true
    }
}
