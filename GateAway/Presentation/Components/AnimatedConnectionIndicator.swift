import SwiftUI

/// Animated connection indicator showing radiowaves
struct AnimatedConnectionIndicator: View {
  @State private var isAnimating = false

  var body: some View {
    Image(systemName: "dot.radiowaves.left.and.right")
      .foregroundColor(.orange)
      .font(.title2)
      .rotationEffect(.degrees(isAnimating ? 360 : 0))
      .onAppear {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
          isAnimating = true
        }
      }
  }
}
