//
//  LegalityGridView.swift
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

struct LegalityGridView: View {
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
                
                Button("Edit") {
                    isEditMode = true
                }
                .font(.subheadline)
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
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workingFormatOrder, id: \.self) { format in
                    Text(format.label).font(.body)
                }
                .onMove { from, to in
                    workingFormatOrder.move(fromOffsets: from, toOffset: to)
                }
                
                // Divider position control
                Section {
                    Stepper(
                        "Show first \(workingDividerIndex) format\(workingDividerIndex == 1 ? "" : "s")",
                        value: $workingDividerIndex,
                        in: 0...workingFormatOrder.count
                    )
                } header: {
                    Text("Visible Formats")
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
                        // Commit changes to the configuration
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
            return "star.fill"
        }
        
        return switch legality {
        case .legal: "checkmark.circle.fill"
        case .notLegal: "xmark.circle.fill"
        case .restricted: "exclamationmark.triangle.fill"
        case .banned: "hand.raised.fill"
        }
    }
    
    private var legalityColor: Color {
        if format == .commander && legality == .legal && isGameChanger {
            // Special color for game changer cards
            return .purple
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
