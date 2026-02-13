import SwiftUI

// MARK: - Onboarding View

/// A multi-step onboarding flow that welcomes the user and guides them
/// through granting Full Disk Access.
struct OnboardingView: View {

    let onComplete: () -> Void

    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            Group {
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    permissionStep
                case 2:
                    readyStep
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(30)

            // Navigation bar
            HStack {
                // Step indicators
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                // Navigation buttons
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                }

                if currentStep < 2 {
                    Button("Next") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 520, height: 460)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Welcome to GlowNotifier")
                .font(.title)
                .fontWeight(.bold)

            Text("GlowNotifier displays a beautiful animated glow around your screen border when notifications arrive. Each app gets its own color — when multiple notifications are active, the colors flow together like a rainbow.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }

    // MARK: - Step 2: Permission

    private var permissionStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Full Disk Access Required")
                .font(.title2)
                .fontWeight(.bold)

            Text("To detect notifications from other apps, GlowNotifier needs to read the system notification database. This requires the \"Full Disk Access\" permission.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("What we access:", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Only the notification database to detect new notifications.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)

                    Label("What we don't access:", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("We never read your files, emails, messages, or any other personal data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                }
                .padding(4)
            }

            Button("Open System Settings") {
                openFullDiskAccessSettings()
            }
            .controlSize(.large)

            Text("After granting access, come back here and click \"Next\".")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Step 3: Ready

    private var readyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.bold)

            Text("GlowNotifier will now run in your menu bar. When a notification arrives from a configured app, your screen border will glow with that app's color.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                tipRow(icon: "paintpalette.fill", text: "Customize colors for each app in Settings")
                tipRow(icon: "slider.horizontal.3", text: "Adjust animation speed and intensity")
                tipRow(icon: "sparkles", text: "Use \"Test Animation\" from the menu bar to preview")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.08)))

            Spacer()
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.callout)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onComplete: {})
    }
}
#endif
