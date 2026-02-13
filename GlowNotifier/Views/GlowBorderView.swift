import SwiftUI

// MARK: - Glow Border View

/// The main visual view that renders the animated breathing glow effect around the screen border.
/// Inspired by the Apple Intelligence Siri activation glow.
///
/// The effect is composed of multiple layers:
/// 1. A sharp, thin gradient border (the "core" line)
/// 2. A medium-blur glow layer for soft illumination
/// 3. A wide-blur ambient layer for the breathing "aura"
struct GlowBorderView: View {

    @ObservedObject var state: GlowBorderState

    var body: some View {
        GeometryReader { geometry in
            if state.isActive && !state.colors.isEmpty {
                ZStack {
                    // Layer 1: Ambient wide glow
                    borderGlow(
                        size: geometry.size,
                        lineWidth: AppSettings.shared.glowWidth * 3.0,
                        blur: 30,
                        opacity: breathingOpacity(base: 0.25)
                    )

                    // Layer 2: Medium glow
                    borderGlow(
                        size: geometry.size,
                        lineWidth: AppSettings.shared.glowWidth * 1.5,
                        blur: 12,
                        opacity: breathingOpacity(base: 0.5)
                    )

                    // Layer 3: Core sharp line
                    borderGlow(
                        size: geometry.size,
                        lineWidth: AppSettings.shared.glowWidth,
                        blur: 3,
                        opacity: breathingOpacity(base: 0.85)
                    )
                }
                .transition(.opacity)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    // MARK: - Border Glow Layer

    @ViewBuilder
    private func borderGlow(
        size: CGSize,
        lineWidth: CGFloat,
        blur: CGFloat,
        opacity: Double
    ) -> some View {
        let gradientStops = buildGradientStops()

        RoundedRectangle(cornerRadius: 0)
            .strokeBorder(
                AngularGradient(
                    stops: gradientStops,
                    center: .center,
                    startAngle: .degrees(360 * Double(state.animationPhase)),
                    endAngle: .degrees(360 * Double(state.animationPhase) + 360)
                ),
                lineWidth: lineWidth
            )
            .frame(width: size.width, height: size.height)
            .blur(radius: blur)
            .opacity(opacity)
    }

    // MARK: - Gradient Construction

    /// Builds gradient stops from the active colors, distributing them evenly
    /// around the angular gradient and adding smooth transitions between them.
    private func buildGradientStops() -> [Gradient.Stop] {
        let colors = state.colors
        guard !colors.isEmpty else { return [] }

        if colors.count == 1 {
            // Single color: create a breathing single-color glow
            let color = colors[0]
            return [
                Gradient.Stop(color: color.opacity(0.9), location: 0.0),
                Gradient.Stop(color: color.opacity(0.5), location: 0.25),
                Gradient.Stop(color: color.opacity(0.9), location: 0.5),
                Gradient.Stop(color: color.opacity(0.5), location: 0.75),
                Gradient.Stop(color: color.opacity(0.9), location: 1.0),
            ]
        }

        // Multiple colors: distribute evenly with smooth transitions (rainbow effect)
        var stops: [Gradient.Stop] = []
        let segmentSize = 1.0 / Double(colors.count)

        for (index, color) in colors.enumerated() {
            let location = Double(index) * segmentSize
            stops.append(Gradient.Stop(color: color, location: location))

            // Add a midpoint with slightly reduced opacity for breathing effect
            let midLocation = location + segmentSize * 0.5
            if midLocation < 1.0 {
                stops.append(Gradient.Stop(
                    color: color.opacity(0.6),
                    location: midLocation
                ))
            }
        }

        // Close the loop: repeat the first color at location 1.0
        stops.append(Gradient.Stop(color: colors[0], location: 1.0))

        return stops
    }

    // MARK: - Breathing Effect

    /// Calculates a pulsing opacity value based on the animation phase.
    private func breathingOpacity(base: Double) -> Double {
        let pulse = sin(Double(state.animationPhase) * .pi * 2.0)
        let intensity = AppSettings.shared.pulseIntensity
        return base + (pulse * intensity * 0.15)
    }
}

// MARK: - Preview

#if DEBUG
struct GlowBorderView_Previews: PreviewProvider {
    static var previews: some View {
        let state = GlowBorderState()
        GlowBorderView(state: state)
            .frame(width: 800, height: 600)
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
