import SwiftUI

struct SearchBarLayout<Content: View>: View {
    enum IconVisibility {
        case progress
        case hidden
        case visible
        case opacity(CGFloat)
    }

    let icon: IconVisibility
    @ViewBuilder let content: () -> Content

    init(icon: IconVisibility = .visible, @ViewBuilder _ content: @escaping () -> Content) {
        self.icon = icon
        self.content = content
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                switch icon {
                case .progress:
                    ProgressView()
                        .controlSize(.small)
                case .hidden:
                    Image(systemName: "magnifyingglass")
                        .hidden()
                case .visible:
                    Image(systemName: "magnifyingglass")
                case .opacity(let opacity):
                    Image(systemName: "magnifyingglass")
                        .opacity(opacity)
                }
            }
            .foregroundStyle(.secondary)
            .frame(width: 16, height: 16)

            content()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}
