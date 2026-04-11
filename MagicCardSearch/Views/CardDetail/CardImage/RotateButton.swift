import SwiftUI

struct RotateButton: View {
    @Binding var rotation: Rotation
    let nonZero: Rotation

    var body: some View {
        Button {
            withAnimation {
                rotation = rotation == .upright ? nonZero : .upright
            }
        } label: {
            Label("Rotate", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
    }
}
