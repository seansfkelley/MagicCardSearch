import SwiftUI

struct FilterPopoverView: View {
    @Binding var filterSettings: AllPrintsFilterSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section("Frame") {
                Picker("Frame", selection: $filterSettings.frame) {
                    ForEach(AllPrintsFilterSettings.FrameFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Text") {
                Picker("Text", selection: $filterSettings.text) {
                    ForEach(AllPrintsFilterSettings.TextFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Game") {
                Picker("Game", selection: $filterSettings.game) {
                    ForEach(AllPrintsFilterSettings.GameFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Picker("Sort", selection: $filterSettings.sort) {
                    ForEach(AllPrintsFilterSettings.SortMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Sort")
            } footer: {
                Text("Sorting by price uses USD only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                filterSettings.reset()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Show All Prints")
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(filterSettings.isDefault ? .gray : .red)
            }
            .buttonStyle(.borderless)
            .disabled(filterSettings.isDefault)
            .padding(.top)
        }
        .padding(20)
        .frame(width: 320)
        .glassEffect(.clear, in: .rect(cornerRadius: 16))
    }
}
