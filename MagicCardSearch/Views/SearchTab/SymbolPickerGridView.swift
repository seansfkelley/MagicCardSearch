import SwiftUI

struct SymbolPickerGridView: View {
    let onSymbolSelected: (SymbolCode) -> Void

    // This stupidity is because the Xcode previews inject a bunch of trampolines to make it
    // live-editable, but something about having the array literals inlined causes the compiler to
    // time out when compiling previews. Pulling them out like this is the only way I could figure
    // out to introduce a type boundary and/or prevent the trampolines from being injected.
    //
    // It didn't use to be this huge 2D array but I figured I might a well if we're doing this in
    // the first place.
    private static let rows: [[SymbolCode]] = [
        ["{T}", "{Q}", "{S}", "{E}", "{P}"],
        ["{W}", "{U}", "{B}", "{R}", "{G}", "{C}"],
        ["{X}", "{1}", "{2}", "{3}", "{4}", "{5}", "{6}", "{7}", "{8}", "{9}"],
        ["{W/U}", "{W/B}", "{U/B}", "{U/R}", "{B/R}", "{B/G}", "{R/W}", "{R/G}", "{G/W}", "{G/U}"],
        ["{2/W}", "{2/U}", "{2/B}", "{2/R}", "{2/G}", "{C/W}", "{C/U}", "{C/B}", "{C/R}", "{C/G}"],
        ["{W/P}", "{U/P}", "{B/P}", "{R/P}", "{G/P}"],
        ["{W/U/P}", "{W/B/P}", "{U/B/P}", "{U/R/P}", "{B/R/P}", "{B/G/P}", "{R/W/P}", "{R/G/P}", "{G/W/P}", "{G/U/P}"],
    ].map { $0.map(SymbolCode.init) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Self.rows.enumerated(), id: \.offset) { _, symbols in
                ViewThatFits {
                    HStack(spacing: 8) {
                        ForEach(symbols, id: \.self) { symbol in
                            Button(action: {
                                onSymbolSelected(symbol)
                            }) {
                                SymbolView(symbol, size: 32, oversize: 32)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(symbols, id: \.self) { symbol in
                                Button(action: {
                                    onSymbolSelected(symbol)
                                }) {
                                    SymbolView(symbol, size: 32, oversize: 32)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
        }
        .padding()
    }
}
