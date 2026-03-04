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
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.1))

                VStack(spacing: 0) {
                    // Name bar
                    Text(name ?? " ")
                        .font(.system(size: height * 0.04, weight: .semibold))
                        .foregroundStyle(Color.gray.opacity(0.8))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, width * 0.02)
                        .padding(.vertical, height * 0.01)
                        .background(Color.gray.opacity(0.10), in: .rect(cornerRadius: height * 0.025, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: height * 0.025, style: .continuous).stroke(Color.gray.opacity(0.2), lineWidth: 2))
                        .padding(.horizontal, width * 0.03)
                        .padding(.top, width * 0.05)

                    // Art frame
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .overlay(alignment: .leading) { Color.gray.opacity(0.2).frame(width: 2) }
                        .overlay(alignment: .trailing) { Color.gray.opacity(0.2).frame(width: 2) }
                        .frame(height: height * 0.44)
                        .padding(.horizontal, width * 0.04)
                        .overlay {
                            switch decoration {
                            case .none:
                                EmptyView()
                            case .spinner:
                                ProgressView()
                                    .controlSize(.large)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                            case .error(let error, _):
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.secondary)
                                        .imageScale(.large)

                                    Text(error.localizedDescription)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }

                    // Type line
                    Text(" ")
                        .font(.system(size: height * 0.04, weight: .semibold))
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, width * 0.01)
                        .padding(.vertical, height * 0.01)
                        .background(Color.gray.opacity(0.10), in: .rect(cornerRadius: height * 0.025, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: height * 0.025, style: .continuous).stroke(Color.gray.opacity(0.2), lineWidth: 2))
                        .padding(.horizontal, width * 0.03)

                    // Text box
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .overlay(alignment: .leading) { Color.gray.opacity(0.2).frame(width: 2) }
                        .overlay(alignment: .trailing) { Color.gray.opacity(0.2).frame(width: 2) }
                        .overlay(alignment: .bottom) { Color.gray.opacity(0.2).frame(height: 2) }
                        .frame(height: height * 0.32)
                        .padding(.horizontal, width * 0.04)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: height * 0.02) {
                                ForEach(0..<3, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(
                                            width: width * (i == 2 ? 0.5 : 0.8),
                                            height: height * 0.03
                                        )
                                }
                            }
                            .padding(.leading, width * 0.1)
                            .padding(.top, height * 0.05)
                        }
                        .overlay {
                            if case .error(_, let retry) = decoration, let retry {
                                Button("Retry") { retry() }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                }
            }
        }
        .aspectRatio(Card.aspectRatio, contentMode: .fit)
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
