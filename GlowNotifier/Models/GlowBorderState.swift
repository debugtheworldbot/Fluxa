import SwiftUI
import AppKit

// MARK: - Glow Border State

/// Observable state object that drives the glow border animation.
/// Each overlay window has its own instance, but they share the same color data.
final class GlowBorderState: ObservableObject {

    @Published var isActive: Bool = false
    @Published var colors: [Color] = []

    /// Continuous animation start time; used by TimelineView to compute phase.
    @Published var animationStartDate: Date?

    init() {}

    /// Updates the active glow colors. Pass an empty array to deactivate.
    func updateColors(_ nsColors: [NSColor]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if nsColors.isEmpty {
                withAnimation(.easeOut(duration: 0.8)) {
                    self.isActive = false
                    self.colors = []
                }
                self.animationStartDate = nil
            } else {
                self.colors = nsColors.map { Color(nsColor: $0) }
                if !self.isActive {
                    withAnimation(.easeIn(duration: 0.5)) {
                        self.isActive = true
                    }
                    self.animationStartDate = Date()
                }
            }
        }
    }

    /// Computes the current animation phase (0...1, wrapping) from a given date.
    func phase(at date: Date) -> CGFloat {
        guard let start = animationStartDate else { return 0 }
        let speed = AppSettings.shared.animationSpeed
        let elapsed = date.timeIntervalSince(start)
        let phase = (elapsed * Double(speed)).truncatingRemainder(dividingBy: 1.0)
        return CGFloat(phase < 0 ? phase + 1.0 : phase)
    }
}
