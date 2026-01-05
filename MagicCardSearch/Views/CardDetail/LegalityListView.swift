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
    
    func update(formatOrder: [Format], dividerIndex: Int) {
        self.formatOrder = formatOrder
        self.dividerIndex = dividerIndex
        save()
    }
}

// MARK: - Main View

struct LegalityListView: View {
    let card: Card
    
    @Bindable var configuration = LegalityConfiguration.shared
    @State private var isEditMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Legality")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    isEditMode = true
                } label: {
                    Text("Edit Visibility")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.automatic)
            }
            
            VStack(spacing: 0) {
                ForEach(Array(configuration.formatOrder.prefix(configuration.dividerIndex)), id: \.self) { format in
                    LegalityItemView(
                        format: format,
                        legality: card.getLegality(for: format),
                        isGameChanger: card.gameChanger ?? false
                    )
                    .padding(.vertical, 4)
                }
            }
        }
        .sheet(isPresented: $isEditMode) {
            LegalityEditView(configuration: configuration)
        }
    }
}

// MARK: - Edit View (Sheet)

private struct LegalityEditView: View {
    @Environment(\.dismiss) private var dismiss
    var configuration: LegalityConfiguration
    
    @State private var workingFormatOrder: [Format]
    @State private var workingDividerIndex: Int
    
    init(configuration: LegalityConfiguration) {
        self.configuration = configuration
        self._workingFormatOrder = State(wrappedValue: configuration.formatOrder)
        self._workingDividerIndex = State(wrappedValue: configuration.dividerIndex)
    }
    
    private func listItems() -> [LegalityListItem] {
        var items: [LegalityListItem] = []
        
        for (index, format) in workingFormatOrder.enumerated() {
            if index == workingDividerIndex {
                items.append(.divider)
            }
            items.append(.format(format))
        }
        
        if workingDividerIndex >= workingFormatOrder.count {
            items.append(.divider)
        }
        
        return items
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(listItems(), id: \.self) { item in
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
                        configuration.update(formatOrder: workingFormatOrder, dividerIndex: workingDividerIndex)
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
        var items = listItems()
        items.move(fromOffsets: source, toOffset: destination)
        workingFormatOrder = items.compactMap { if case .format(let format) = $0 { format } else { nil } }
        workingDividerIndex = items.firstIndex(of: .divider)!
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
                .font(.body)
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
