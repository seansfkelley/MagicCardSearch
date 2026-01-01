//
//  BottomBarFilterView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-06.
//
import SwiftUI

struct SearchBarAndPillsView: View {
    @Binding var searchState: SearchState
    let isAutocompleteLoading: Bool
    let onFilterEdit: (SearchFilter) -> Void
    let onClearAll: () -> Void
    let onSubmit: () -> Void

    @State var showWarningsPopover: Bool = false
    @Namespace private var animation
    
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
                    Button(role: .destructive, action: onClearAll) {
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
                        filters: $searchState.filters,
                        maxRows: maxPillRows,
                        onEdit: onFilterEdit
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

                SearchBarView(
                    filters: $searchState.filters,
                    inputText: $searchState.searchText,
                    inputSelection: $searchState.searchSelection,
                    isAutocompleteLoading: isAutocompleteLoading,
                    searchState: searchState,
                    onSubmit: onSubmit,
                )
            }
            .contentShape(Rectangle())
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}
