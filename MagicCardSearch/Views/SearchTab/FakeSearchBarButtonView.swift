import SwiftUI

struct FakeSearchBarButtonView: View {
    @Binding var searchState: SearchState
    var onTap: () -> Void

    @State var showWarningsPopover: Bool = false
    @State var searchIconOpacity: CGFloat = 1
    @Namespace private var animation
    
    private let buttonSize: CGFloat = 44
    private let searchIconFadeExtent: CGFloat = 24

    var body: some View {
        let warnings = searchState.results?.value.latestValue?.warnings ?? []

        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                if showWarningsPopover {
                    WarningsPillView(
                        warnings: warnings,
                        mode: .pill,
                        isExpanded: $showWarningsPopover
                    )
                    .matchedGeometryEffect(id: "warnings", in: animation)
                }
            }
            .padding(.bottom, showWarningsPopover ? 8 : 0)
            
            HStack {
                if !showWarningsPopover {
                    WarningsPillView(
                        warnings: warnings,
                        mode: .icon(buttonSize),
                        isExpanded: $showWarningsPopover
                    )
                    .matchedGeometryEffect(id: "warnings", in: animation)
                }
                
                ZStack {
                    SearchBarLayout(icon: .opacity(searchIconOpacity)) {
                        TextField(searchState.filters.isEmpty ? "Search for cards..." : "", text: .constant(""))
                            .disabled(true)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        SearchBarLayout(icon: .hidden) {
                            ForEach(searchState.filters, id: \.self) { filter in
                                FilterPillView(filter: filter)
                            }
                        }
                    }
                    .onScrollGeometryChange(
                        for: CGFloat.self,
                        of: { geometry in
                            let x = geometry.contentOffset.x
                            return x > searchIconFadeExtent ? searchIconFadeExtent : x < 0 ? 0 : x
                        },
                        action: { _, currentValue in
                            searchIconOpacity = (searchIconFadeExtent - currentValue) / searchIconFadeExtent
                        })
                    .clipShape(.capsule)
                    .frame(maxWidth: .infinity)
                    .frame(height: buttonSize)
                }
                .contentShape(Rectangle())
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                .simultaneousGesture(TapGesture().onEnded { onTap() })

                if !searchState.filters.isEmpty {
                    Spacer()
                    Button(action: {
                        searchState.clearAll()
                        onTap()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                            .font(.system(size: 20))
                            .frame(width: buttonSize, height: buttonSize)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive())
                }
            }
        }
    }
}
