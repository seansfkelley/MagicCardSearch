import SwiftUI

struct ReflowingFilterPillsView: View {
    @Binding var filters: [SearchFilter]
    let maxRows: Int
    let onEdit: (SearchFilter) -> Void
    
    @State private var pillSizes: [SearchFilter: CGSize] = [:]
    
    private let horizontalSpacing: CGFloat = 8
    private let verticalSpacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 12
    private let verticalPadding: CGFloat = 8
    private let pillHeight: CGFloat = 32
    // Just a SWAG that probably doesn't really matter.
    private let estimatedPillWidth: CGFloat = 120
    
    private var maxHeight: CGFloat {
        let totalLineHeight = pillHeight + verticalSpacing
        let totalVerticalPadding = verticalPadding * 2
        return (totalLineHeight * CGFloat(maxRows)) - verticalSpacing + totalVerticalPadding
    }
    
    var body: some View {
        let rows = reflowedRows(availableWidth: availableWidth)
        // Nasty. I would prefer it to just grow until it hits the limit, but I think the
        // GeometryReader is causing it to grow to its maximum size eagerly and not letting
        // the content do it, so just calculate the right size instead.
        let requiredHeight = calculateActualHeight(rowCount: rows.count)
        
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: verticalSpacing) {
                ForEach(rows, id: \.id) { row in
                    HStack(spacing: horizontalSpacing) {
                        ForEach(row.items, id: \.filter) { item in
                            FilterPillView(
                                filter: item.filter,
                                onTap: {
                                    filters.remove(at: item.index)
                                    onEdit(item.filter)
                                },
                                onDelete: {
                                    filters.remove(at: item.index)
                                }
                            )
                            .background(
                                GeometryReader { pillGeometry in
                                    Color.clear
                                        .onAppear {
                                            pillSizes[item.filter] = pillGeometry.size
                                        }
                                        .onChange(of: pillGeometry.size) { _, newValue in
                                            pillSizes[item.filter] = newValue
                                        }
                                }
                            )
                        }
                    }
                    .frame(minWidth: availableWidth > 0 ? availableWidth - (horizontalPadding * 2) : nil, alignment: .leading)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
        }
        .scrollIndicators(.hidden)
        // Somehow, this pair of methods will do the right thing horizontally, whereas using the
        // shorthand without the `axes` argument will still bounce horizontally. Why??
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .frame(height: min(requiredHeight, maxHeight))
        .overlay(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        availableWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { _, newValue in
                        availableWidth = newValue
                    }
            }
            .allowsHitTesting(false)
        )
        .mask {
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
                Rectangle()
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
            }
        }
    }
    
    private func calculateActualHeight(rowCount: Int) -> CGFloat {
        guard rowCount > 0 else { return 0 }
        let totalLineHeight = pillHeight + verticalSpacing
        let totalVerticalPadding = verticalPadding * 2
        return (totalLineHeight * CGFloat(rowCount)) - verticalSpacing + totalVerticalPadding
    }
    
    @State private var availableWidth: CGFloat = 0
    
    private struct FilterItem: Hashable {
        let filter: SearchFilter
        let index: Int
    }
    
    private struct FilterRow: Identifiable {
        let id = UUID()
        let items: [FilterItem]
    }
    
    private func reflowedRows(availableWidth: CGFloat) -> [FilterRow] {
        var rows: [FilterRow] = []
        var currentRow: [FilterItem] = []
        var currentRowWidth: CGFloat = 0
        
        let effectiveWidth = availableWidth - (horizontalPadding * 2)
        
        guard effectiveWidth > 0 else { return [] }
        
        for (index, filter) in filters.enumerated() {
            let pillWidth = pillSizes[filter]?.width ?? estimatedPillWidth
            
            let widthWithPill: CGFloat
            if currentRow.isEmpty {
                widthWithPill = pillWidth
            } else {
                widthWithPill = currentRowWidth + horizontalSpacing + pillWidth
            }
            
            if widthWithPill <= effectiveWidth || currentRow.isEmpty {
                currentRow.append(FilterItem(filter: filter, index: index))
                currentRowWidth = widthWithPill
            } else {
                if !currentRow.isEmpty {
                    rows.append(FilterRow(items: currentRow))
                }
                currentRow = [FilterItem(filter: filter, index: index)]
                currentRowWidth = pillWidth
            }
        }
        
        if !currentRow.isEmpty {
            rows.append(FilterRow(items: currentRow))
        }
        
        return rows
    }
}
