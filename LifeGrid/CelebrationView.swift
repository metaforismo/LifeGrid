import SwiftUI

/// A brief, non-interactive confetti burst shown when all of a day's goals are
/// completed. Pieces fall and fade once; the parent removes the view after a
/// short delay.
struct CelebrationView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let color: Color
        let delay: Double
        let rotation: Double
        let size: CGFloat
    }

    private let pieces: [Piece]
    @State private var animate = false

    init(count: Int = 70) {
        let colors: [Color] = [
            LifeGridTheme.green, LifeGridTheme.purple, .pink, .orange, .cyan, .yellow,
        ]
        pieces = (0 ..< count).map { _ in
            Piece(
                x: .random(in: 0 ... 1),
                color: colors.randomElement() ?? LifeGridTheme.green,
                delay: .random(in: 0 ... 0.35),
                rotation: .random(in: 0 ... 360),
                size: .random(in: 6 ... 11)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 1.5)
                        .rotationEffect(.degrees(animate ? piece.rotation + 220 : piece.rotation))
                        .position(
                            x: piece.x * geo.size.width,
                            y: animate ? geo.size.height + 40 : -40
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(.easeIn(duration: 1.9).delay(piece.delay), value: animate)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear { animate = true }
    }
}

#Preview {
    ZStack {
        Color.black
        CelebrationView()
    }
}
