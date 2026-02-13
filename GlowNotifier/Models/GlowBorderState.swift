import SwiftUI
import AppKit

// MARK: - Glow Border State

/// Observable state object that drives the glow border animation.
/// Each overlay window has its own instance, but they share the same color data.
final class GlowBorderState: ObservableObject {

    @Published var isActive: Bool = false
    @Published var colors: [Color] = []
    @Published var animationPhase: CGFloat = 0.0

    private var animationTimer: Timer?

    init() {}

    /// Updates the active glow colors. Pass an empty array to deactivate.
    func updateColors(_ nsColors: [NSColor]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if nsColors.isEmpty {
                self.stopAnimation()
                withAnimation(.easeOut(duration: 0.8)) {
                    self.isActive = false
                    self.colors = []
                }
            } else {
                self.colors = nsColors.map { Color(nsColor: $0) }
                if !self.isActive {
                    withAnimation(.easeIn(duration: 0.5)) {
                        self.isActive = true
                    }
                    self.startAnimation()
                }
            }
        }
    }

    // MARK: - Animation Loop

    private func startAnimation() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let speed = AppSettings.shared.animationSpeed
            self.animationPhase += speed / 60.0
            if self.animationPhase > 1.0 {
                self.animationPhase -= 1.0
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationPhase = 0.0
    }
}
