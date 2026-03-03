import SwiftUI
import ScryfallKit

struct CardPlaceholderView: View {
    enum Decoration {
        case none, spinner
        case error(any Error, () -> Void)
    }

    let name: String?
    let cornerRadius: CGFloat
    let decoration: Decoration

    init(name: String?, cornerRadius: CGFloat, with decoration: Decoration = .none) {
        self.name = name
        self.cornerRadius = cornerRadius
        self.decoration = decoration
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(Card.aspectRatio, contentMode: .fit)
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        if let name {
                            Text(name)
                                .font(.title3)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                )

            switch decoration {
            case .none:
                EmptyView()
            case .spinner:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(Card.aspectRatio, contentMode: .fit)
                    .background(Color(.systemGray6).opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            case .error(let error, let retry):
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        if let name {
                            Text("Failed to load \(name)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        Text(error.localizedDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    Button("Retry") {
                        retry()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct PreviewError: LocalizedError {
    var errorDescription: String? { "Could not connect to Scryfall." }
}
#Preview {
    let names: [String?] = [nil, "Lightning Bolt"]
    let decorations: [(String, CardPlaceholderView.Decoration)] = [
        ("none", .none),
        ("spinner", .spinner),
        ("error", .error(PreviewError(), {})),
    ]

    ScrollView {
        Grid(horizontalSpacing: 12, verticalSpacing: 24) {
            GridRow {
                Color.clear.gridCellUnsizedAxes(.vertical)
                ForEach(names, id: \.self) { name in
                    Text(name ?? "nil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(decorations, id: \.0) { label, decoration in
                GridRow {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .gridCellAnchor(.trailing)
                    ForEach(names, id: \.self) { name in
                        CardPlaceholderView(name: name, cornerRadius: 16, with: decoration)
                    }
                }
            }
        }
        .padding()
    }
}
