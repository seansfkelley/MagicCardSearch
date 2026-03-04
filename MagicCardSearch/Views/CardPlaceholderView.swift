import SwiftUI
import ScryfallKit

struct CardPlaceholderView: View {
    enum Decoration {
        case none, spinner
        case error(any Error, (() -> Void)?)
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
            cardShape
                .aspectRatio(Card.aspectRatio, contentMode: .fit)
                .overlay { decorationOverlay }
        }
    }

    private var cardShape: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let inset = width * 0.05
            let artHeight = height * 0.45
            let textBoxHeight = height * 0.35

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.2))

                VStack(spacing: inset * 0.6) {
                    // Name bar
                    if let name {
                        Text(name)
                            .font(.system(size: height * 0.04, weight: .semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, inset * 0.5)
                            .padding(.vertical, inset * 0.3)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius * 0.3))
                    }

                    // Art frame
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: artHeight)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: height * 0.1))
                                .foregroundStyle(.tertiary)
                        }

                    // Text box
                    RoundedRectangle(cornerRadius: cornerRadius * 0.3)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: textBoxHeight)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: height * 0.015) {
                                ForEach(0..<3, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(
                                            width: width * (i == 2 ? 0.5 : 0.8),
                                            height: height * 0.02
                                        )
                                }
                            }
                            .padding(inset * 0.8)
                        }
                }
                .padding(inset)
            }
        }
    }

    @ViewBuilder
    private var decorationOverlay: some View {
        switch decoration {
        case .none:
            EmptyView()
        case .spinner:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        case .error(let error, let retry):
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .imageScale(.large)
                if let name {
                    Text("Failed to load \(name)")
                        .fontWeight(.semibold)
                }
                Text(error.localizedDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let retry {
                    Button("Retry") { retry() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        ("error", .error(PreviewError(), nil)),
        ("error with retry", .error(PreviewError(), {})),
    ]

    ScrollView {
        ForEach(decorations, id: \.0) { label, decoration in
            ForEach(names, id: \.self) { name in
                VStack(alignment: .leading) {
                    Text("name: \(name ?? "nil"), decoration: \(label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    CardPlaceholderView(name: name, cornerRadius: 16, with: decoration)
                }
            }
        }
        .padding()
    }
}
