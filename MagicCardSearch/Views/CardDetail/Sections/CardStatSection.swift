import SwiftUI

struct CardStatSection: View {
    let value: String
    let label: String?

    init(value: String, label: String? = nil) {
        self.value = value
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                if let label = label {
                    Text("\(label):")
                        .font(.body)
                        .fontWeight(.semibold)
                }

                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
