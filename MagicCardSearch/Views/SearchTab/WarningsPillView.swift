import SwiftUI

struct WarningsPillView: View {
    enum ButtonMode {
        case icon(CGFloat)
        case pill
    }

    let warnings: [String]
    let mode: ButtonMode
    @Binding var isExpanded: Bool
    
    var body: some View {
        if warnings.isEmpty {
            EmptyView()
        } else if isExpanded {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(warnings.enumerated()), id: \.element) { index, warning in
                    Text(warning)
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if index < warnings.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .onTapGesture {
                if isExpanded {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }
            }
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isExpanded = true
                }
            }) {
                switch mode {
                case .icon(let size):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 20))
                        .frame(width: size, height: size)
                        .glassEffect(.regular.interactive(), in: .circle)
                case .pill:
                    Text(warnings.count == 1 ? "1 warning" : "\(warnings.count) warnings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
        }
    }
}
