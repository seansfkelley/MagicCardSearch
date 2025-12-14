//
//  LegalityListView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI
import ScryfallKit

// MARK: - Legality Configuration Manager

@MainActor
@Observable
class LegalityConfiguration {
    static let shared = LegalityConfiguration()
    
    private let userDefaultsKey = "legalityFormatOrder"
    private let dividerIndexKey = "legalityDividerIndex"
    
    var formatOrder: [Format]
    var dividerIndex: Int
    
    private init() {
        let defaultDividerIndex = 5
        let defaultOrder: [Format] = [
            .commander,
            .standard,
            .modern,
            .legacy,
            .pauper,
            // below the fold!
            .alchemy,
            .brawl,
            .duel,
            .future,
            .gladiator,
            .historic,
            .oathbreaker,
            .oldschool,
            .paupercommander,
            .penny,
            .pioneer,
            .predh,
            .premodern,
            .standardbrawl,
            .timeless,
            .vintage,
        ]
        
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: savedData) {
            let savedFormats = decoded.compactMap { Format(rawValue: $0) }
            
            var mergedOrder = savedFormats
            for format in defaultOrder where !mergedOrder.contains(format) {
                mergedOrder.append(format)
            }
            
            self.formatOrder = mergedOrder
        } else {
            self.formatOrder = defaultOrder
        }
        
        self.dividerIndex = UserDefaults.standard
            .object(forKey: dividerIndexKey) as? Int ?? defaultDividerIndex
        
        if dividerIndex > formatOrder.count {
            dividerIndex = formatOrder.count
        }
    }
    
    func save() {
        let rawValues = formatOrder.map { $0.rawValue }
        if let encoded = try? JSONEncoder().encode(rawValues) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
        UserDefaults.standard.set(dividerIndex, forKey: dividerIndexKey)
    }
    
    func moveFormat(from: IndexSet, to: Int) {
        formatOrder.move(fromOffsets: from, toOffset: to)
        save()
    }
    
    func setDividerIndex(_ index: Int) {
        dividerIndex = min(max(0, index), formatOrder.count)
        save()
    }
}

// MARK: - Main View

struct LegalityListView: View {
    let card: Card
    
    @State private var configuration = LegalityConfiguration.shared
    @State private var isExpanded = false
    @State private var isEditMode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Legality")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    isEditMode = true
                } label: {
                    Image(systemName: "pencil")
                        .imageScale(.small)
                }
            }
            .padding(.bottom, 12)
            
            normalView
        }
        .sheet(isPresented: $isEditMode) {
            LegalityEditView(configuration: configuration)
        }
    }
    
    private var normalView: some View {
        VStack(spacing: 0) {
            ForEach(visibleFormats, id: \.self) { format in
                LegalityItemView(
                    format: format,
                    legality: card.getLegality(for: format),
                    isGameChanger: card.gameChanger ?? false
                )
                .padding(.vertical, 4)
            }
            
            if hasHiddenFormats {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? "Show Less" : "Show More")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var visibleFormats: [Format] {
        if isExpanded {
            return Array(configuration.formatOrder)
        } else {
            return Array(configuration.formatOrder.prefix(configuration.dividerIndex))
        }
    }
    
    private var hasHiddenFormats: Bool {
        configuration.dividerIndex < configuration.formatOrder.count
    }
}

// MARK: - Edit View (Sheet)

private struct LegalityEditView: View {
    @Environment(\.dismiss) private var dismiss
    var configuration: LegalityConfiguration
    
    // Local state that will only be applied on confirmation
    @State private var workingFormatOrder: [Format]
    @State private var workingDividerIndex: Int
    
    init(configuration: LegalityConfiguration) {
        self.configuration = configuration
        // Initialize working state with current configuration
        self._workingFormatOrder = State(wrappedValue: configuration.formatOrder)
        self._workingDividerIndex = State(wrappedValue: configuration.dividerIndex)
    }
    
    // Create a combined list with formats and divider
    private var listItems: [LegalityListItem] {
        var items: [LegalityListItem] = []
        
        for (index, format) in workingFormatOrder.enumerated() {
            // Insert divider before this format if it matches the divider index
            if index == workingDividerIndex {
                items.append(.divider)
            }
            items.append(.format(format))
        }
        
        // If divider is at the end, add it after all formats
        if workingDividerIndex >= workingFormatOrder.count {
            items.append(.divider)
        }
        
        return items
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(listItems, id: \.self) { item in
                    switch item {
                    case .format(let format):
                        Text(format.label).font(.body)
                    case .divider:
                        Rectangle()
                            .fill(.tertiary)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                    }
                }
                .onMove { from, to in
                    handleMove(from: from, to: to)
                }
            }
            .navigationTitle("Edit Visible Legalities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        configuration.formatOrder = workingFormatOrder
                        configuration.dividerIndex = workingDividerIndex
                        configuration.save()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }
    
    private func handleMove(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        
        let items = listItems
        let movingItem = items[sourceIndex]
        
        switch movingItem {
        case .format:
            // Moving a format - need to adjust for divider position
            let formatSourceIndex = formatIndex(at: sourceIndex, in: items)
            var formatDestIndex = formatIndex(at: destination, in: items)
            
            // If we're moving past the divider, adjust the destination
            if sourceIndex < destination {
                // Moving down - destination already accounts for removal
                formatDestIndex = formatIndex(at: destination - 1, in: items)
            }
            
            // Move the format
            workingFormatOrder.move(fromOffsets: IndexSet([formatSourceIndex]), toOffset: formatDestIndex)
            
            // Adjust divider index if needed
            if formatSourceIndex < workingDividerIndex && formatDestIndex >= workingDividerIndex {
                // Moved from above to below divider
                workingDividerIndex -= 1
            } else if formatSourceIndex >= workingDividerIndex && formatDestIndex < workingDividerIndex {
                // Moved from below to above divider
                workingDividerIndex += 1
            }
            
        case .divider:
            // Moving the divider - update its position
            var newDividerIndex = formatIndex(at: destination, in: items)
            
            // Adjust for the current direction of movement
            if sourceIndex < destination {
                // Moving down - the destination index accounts for divider removal
                newDividerIndex = formatIndex(at: destination - 1, in: items)
            }
            
            workingDividerIndex = newDividerIndex
        }
    }
    
    // Helper to find the format index (excluding divider) at a given list position
    private func formatIndex(at listIndex: Int, in items: [LegalityListItem]) -> Int {
        var formatCount = 0
        for i in 0..<min(listIndex, items.count) {
            if case .format = items[i] {
                formatCount += 1
            }
        }
        return formatCount
    }
    
    private enum LegalityListItem: Equatable, Hashable {
        case format(Format)
        case divider
    }
}

// MARK: - Legality Item View

private struct LegalityItemView: View {
    let format: Format
    let legality: Card.Legality
    let isGameChanger: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text(format.label)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 6) {
                Image(systemName: legalityIcon)
                    .font(.caption)
                    .foregroundStyle(.white)
                
                Text(legalityDisplayText.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(legalityColor)
            )
        }
    }
    
    private var legalityDisplayText: String {
        return if format == .commander && isGameChanger {
            "\(legality.label)/GC"
        } else {
            legality.label
        }
    }
    
    private var legalityIcon: String {
        if format == .commander && legality == .legal && isGameChanger {
            return "exclamationmark"
        }
        
        return switch legality {
        case .legal: "checkmark"
        case .notLegal: "xmark"
        case .restricted: "exclamationmark"
        case .banned: "circle.slash"
        }
    }
    
    private var legalityColor: Color {
        if format == .commander && legality == .legal && isGameChanger {
            // TODO: Different color?
            return .green
        } else {
            return switch legality {
            case .legal: .green
            case .notLegal: .gray
            case .restricted: .orange
            case .banned: .red
            }
        }
    }
}
// MARK: - Previews

#Preview("All Legality States") {
    VStack(spacing: 16) {
        LegalityItemView(
            format: .standard,
            legality: .legal,
            isGameChanger: false
        )
    
        LegalityItemView(
            format: .commander,
            legality: .legal,
            isGameChanger: true
        )
        
        LegalityItemView(
            format: .modern,
            legality: .notLegal,
            isGameChanger: false
        )
        
        LegalityItemView(
            format: .vintage,
            legality: .restricted,
            isGameChanger: false
        )
        
        LegalityItemView(
            format: .legacy,
            legality: .banned,
            isGameChanger: false
        )
    }
    .padding(.vertical)
}
