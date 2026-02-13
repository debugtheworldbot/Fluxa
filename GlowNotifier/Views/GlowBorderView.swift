import SwiftUI

// MARK: - Glow Border View

/// Renders aggregated unread-notification colors inside an Apple logo shape.
/// The gradient flow is intentionally slow and continuous.
struct GlowBorderView: View {

    @ObservedObject var state: GlowBorderState
    @ObservedObject var appSettings: AppSettings = .shared
    var hasNotch: Bool = false
    private let showUnclippedDebug = false

    var body: some View {
        ZStack {
            if showUnclippedDebug {
                ZStack {
                    appleIcon(color: .black)
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.yellow.opacity(0.95), lineWidth: 1)
                }
            } else if !state.isActive || state.colors.isEmpty {
                appleIcon(color: Color(nsColor: appSettings.defaultIconColor))
            } else if state.isActive && !state.colors.isEmpty {
                TimelineView(.animation) { timeline in
                    let phase = state.phase(at: timeline.date)
                    let palette = normalizedPalette()
                    flowingColorLayers(phase: phase, palette: palette)
                        .frame(width: 16, height: 17)
                        .clipped()
                        .compositingGroup()
                        .mask { appleIcon(color: .white) }
                }
                .transition(.opacity)
            }
        }
        .offset(y: hasNotch ? -1.5 : 0)
        .frame(width: 24, height: 24)
        .allowsHitTesting(false)
    }

    /// Renders the Apple logo using `.font()` sizing to match system menu bar rendering.
    @ViewBuilder
    private func appleIcon(color: Color) -> some View {
        let size: CGFloat = 17
        let w: Font.Weight = .black
        ZStack {
            Image(systemName: "apple.logo").font(.system(size: size, weight: w)).foregroundColor(color)
            Image(systemName: "apple.logo").font(.system(size: size, weight: w)).foregroundColor(color).offset(x: 0.3)
            Image(systemName: "apple.logo").font(.system(size: size, weight: w)).foregroundColor(color).offset(x: -0.3)
            Image(systemName: "apple.logo").font(.system(size: size, weight: w)).foregroundColor(color).offset(y: 0.3)
            Image(systemName: "apple.logo").font(.system(size: size, weight: w)).foregroundColor(color).offset(y: -0.3)
        }
        .frame(width: 18, height: 19)
    }

    // MARK: - Flowing Color Layers

    @ViewBuilder
    private func flowingColorLayers(phase: CGFloat, palette: [Color]) -> some View {
        let width: CGFloat = 16
        let height: CGFloat = 17
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
