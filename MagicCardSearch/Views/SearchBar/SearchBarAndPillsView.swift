//
//  BottomBarFilterView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-06.
//
import SwiftUI
import WrappingHStack

struct SearchBarAndPillsView: View {
    @Binding var filters: [SearchFilter]
    let warnings: [String]
    @Binding var inputText: String
    @Binding var inputSelection: TextSelection?
    @Bindable var autocompleteProvider: CombinedSuggestionProvider
    let searchHistoryTracker: SearchHistoryTracker
    let onFilterEdit: (SearchFilter) -> Void
    let onClearAll: () -> Void
    let onSubmit: () -> Void

    @State var showWarningsPopover: Bool = false
    @State var searchIconOpacity: CGFloat = 1
    
    @Namespace private var animation
    
    private let collapsedButtonSize: CGFloat = 44
    private let searchIconFadeExtent: CGFloat = 24
    
    // Calculate max height based on pill dimensions without hardcoding
    // Each pill is 32pt tall with 8pt spacing = 40pt per line
    // 3.5 lines = 3.5 * 40 = 140pt
    private var maxPillsHeight: CGFloat {
        let pillHeight: CGFloat = 32
        let lineSpacing: CGFloat = 8
        let lines: CGFloat = 4
        return (pillHeight + lineSpacing) * lines
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                WarningsPillView(
                    warnings: warnings,
                    mode: .pill,
                    isExpanded: $showWarningsPopover
                )
                Spacer()
                if !filters.isEmpty {
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
                if !filters.isEmpty {
                    ScrollView {
                        WrappingHStack(
                            // n.b. you can't use ForEach here as a limitation of the library, so pass the list of
                            // things to render to the stack.
                            filters.enumerated(),
                            alignment: .leading,
                            spacing: .constant(8),
                            lineSpacing: 8
                        ) { index, filter in
                            FilterPillView(
                                filter: filter,
                                onTap: {
                                    onFilterEdit(filter)
                                    filters.remove(at: index)
                                },
                                onDelete: {
                                    filters.remove(at: index)
                                }
                            )
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .frame(maxHeight: maxPillsHeight)
                    .fixedSize(horizontal: false, vertical: true)
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
                    filters: $filters,
                    inputText: $inputText,
                    inputSelection: $inputSelection,
                    autocompleteProvider: autocompleteProvider,
                    searchHistoryTracker: searchHistoryTracker,
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
