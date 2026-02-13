import SwiftUI

// MARK: - Glow Border View

/// Renders aggregated unread-notification colors inside an Apple logo shape.
/// The gradient flow is intentionally slow and continuous.
struct GlowBorderView: View {

    @ObservedObject var state: GlowBorderState
    private let showUnclippedDebug = false
    private let appleMaskOffset = CGSize(width: 0, height: 0)

    var body: some View {
        GeometryReader { geometry in
            if showUnclippedDebug {
                ZStack {
                    appleMask(size: geometry.size, color: .black)

                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.yellow.opacity(0.95), lineWidth: 1)
                }
            } else if !state.isActive || state.colors.isEmpty {
                appleMask(size: geometry.size, color: .black)
            } else if state.isActive && !state.colors.isEmpty {
                let phase = state.animationPhase
                let palette = normalizedPalette()
                flowingColorLayers(size: geometry.size, phase: phase, palette: palette)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .compositingGroup()
                    .mask {
                        appleMask(size: geometry.size)
                    }
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func appleMask(size: CGSize, color: Color = .white) -> some View {
        Image(systemName: "apple.logo")
            .resizable()
            .scaledToFit()
            .frame(
                width: min(size.width, size.height) * 0.73,
                height: min(size.width, size.height) * 0.73,
                alignment: .center
            )
            .foregroundStyle(color)
            .frame(width: size.width, height: size.height)
            .offset(appleMaskOffset)
            .contentShape(Rectangle())
    }

    // MARK: - Flowing Color Layers

    @ViewBuilder
    private func flowingColorLayers(size: CGSize, phase: CGFloat, palette: [Color]) -> some View {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let flow = Double(phase) * .pi * 2.0

        ZStack {
            Rectangle()
                .fill((palette.first ?? .white).opacity(0.9))

            LinearGradient(
                colors: palette + [palette.first ?? .white],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 2.2, height: height * 1.6)
            .offset(
                x: CGFloat(cos(flow * 0.55)) * width * 0.24,
                y: CGFloat(sin(flow * 0.40)) * height * 0.10
            )
            .opacity(0.9)
            .blur(radius: 0.45)

            LinearGradient(
                colors: Array(palette.reversed()) + [palette.last ?? .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: width * 2.0, height: height * 1.8)
            .offset(
                x: CGFloat(sin(flow * 0.45 + 1.0)) * width * 0.18,
                y: CGFloat(cos(flow * 0.35 + 0.8)) * height * 0.14
            )
            .opacity(0.75)
            .blendMode(.screen)
            .blur(radius: 0.75)

            AngularGradient(
                colors: palette + [palette.first ?? .white],
                center: .center,
                startAngle: .degrees(Double(phase) * 360.0 * 0.35),
                endAngle: .degrees(Double(phase) * 360.0 * 0.35 + 360.0)
            )
            .frame(width: width * 1.4, height: height * 1.4)
            .offset(
                x: CGFloat(sin(flow * 0.25)) * width * 0.08,
                y: CGFloat(cos(flow * 0.30)) * height * 0.08
            )
            .opacity(0.55)
            .blendMode(.plusLighter)
            .blur(radius: 0.6)
        }
    }

    // MARK: - Colors

    private func normalizedPalette() -> [Color] {
        if state.colors.count <= 1 {
            let color = state.colors.first ?? .white
            return [
                color.opacity(0.35),
                color.opacity(0.95),
                color.opacity(0.60),
                color.opacity(0.85),
            ]
        }

        return state.colors.map { $0.opacity(0.95) }
    }

    private func debugPalette() -> [Color] {
        if state.colors.isEmpty {
            return [
                Color.red.opacity(0.9),
                Color.orange.opacity(0.9),
                Color.pink.opacity(0.9),
                Color.blue.opacity(0.9),
            ]
        }
        return normalizedPalette()
    }

}

// MARK: - Preview

#if DEBUG
struct GlowBorderView_Previews: PreviewProvider {
    static var previews: some View {
        let state = GlowBorderState()
        GlowBorderView(state: state)
            .frame(width: 48, height: 40)
            .background(Color.black)
            .onAppear {
                state.updateColors([
                    NSColor.systemPurple,
                    NSColor.systemPink,
                    NSColor.systemBlue,
                ])
            }
    }
}
#endif
