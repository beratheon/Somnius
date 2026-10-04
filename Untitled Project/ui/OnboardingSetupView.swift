import SwiftUI
import AppKit

struct OnboardingSetupView: View {
    var onComplete: () -> Void

    @State private var selectedMode: String? = nil
    @State private var debridApiKeyInput: String = Config.realDebridApiKey
    @State private var showKeyInputSheet: Bool = false
    @State private var hoveredCard: String? = nil

    var body: some View {
        ZStack {
            // macOS Dark Acrylic Background
            Color(red: 0.06, green: 0.06, blue: 0.07)
                .ignoresSafeArea()

            // Subtle Background Ambient Gradient
            RadialGradient(
                colors: [Color.purple.opacity(0.12), Color.blue.opacity(0.08), Color.clear],
                center: .top,
                startRadius: 50,
                endRadius: 700
            )
            .ignoresSafeArea()

            VStack(spacing: 36) {
                // Header & Brand
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 48, height: 48)
                                .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 3)

                            Image(systemName: "play.tv.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("Welcome to Untitled Streamer")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(.white)
                    }

                    Text("Choose your preferred streaming engine. You can change this or add accounts anytime in Settings.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 580)
                }
                .padding(.top, 24)

                // Two Huge Square Cards Side-by-Side
                HStack(spacing: 28) {
                    // 1. Classic Setup Card
                    setupOptionCard(
                        id: "classic",
                        title: "Classic Setup",
                        subtitle: "Direct & Fast P2P Streaming",
                        badge: "Free & Built-in",
                        badgeColor: .blue,
                        icon: "play.circle.fill",
                        iconGradient: [.blue, .cyan],
                        bullets: [
                            "Stream directly from fast, verified peers",
                            "Automatically filtered for high-speed seeders",
                            "Zero external accounts or subscriptions needed",
                            "Instant start with built-in hardware acceleration"
                        ],
                        actionTitle: "Select Classic Mode",
                        action: {
                            Config.streamingSetupMode = "classic"
                            Config.hasCompletedOnboarding = true
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onComplete()
                            }
                        }
                    )

                    // 2. Debrid Setup Card
                    setupOptionCard(
                        id: "debrid",
                        title: "Debrid Setup",
                        subtitle: "High-Speed Encrypted Cloud CDN",
                        badge: "Recommended for 4K",
                        badgeColor: .purple,
                        icon: "bolt.shield.fill",
                        iconGradient: [.purple, .indigo],
                        bullets: [
                            "Multi-gigabit cloud CDN for 80GB+ 4K Remuxes",
                            "Full Dolby Vision & Dolby Atmos uncompressed audio",
                            "No peer seeding, torrent throttling, or IP exposure",
                            "Connects seamlessly with your Real-Debrid API key"
                        ],
                        actionTitle: "Select Debrid Mode",
                        action: {
                            Config.streamingSetupMode = "debrid"
                            showKeyInputSheet = true
                        }
                    )
                }

                Text("4K · HDR · Multi-Audio & Subtitles")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 12)
            }
            .padding(40)

            // Debrid API Key Sheet / Modal
            if showKeyInputSheet {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.orange)
                        Text("Connect Real-Debrid")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { showKeyInputSheet = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Paste your Real-Debrid API token below to enable high-speed 4K streaming. You can also skip this and enter it later.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SecureField("Paste your API token here...", text: $debridApiKeyInput)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        Button(action: {
                            if let url = URL(string: "https://real-debrid.com/apitoken") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("Get API Token")
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button("Skip for Now") {
                            Config.realDebridApiKey = ""
                            Config.hasCompletedOnboarding = true
                            showKeyInputSheet = false
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onComplete()
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Save & Start Streaming") {
                            let clean = debridApiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            Config.realDebridApiKey = clean
                            Config.hasCompletedOnboarding = true
                            showKeyInputSheet = false
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onComplete()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                }
                .padding(24)
                .frame(width: 480)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
                .shadow(color: .black.opacity(0.8), radius: 30)
                .zIndex(100)
            }
        }
    }

    // MARK: - Huge Square Setup Option Card
    @ViewBuilder
    private func setupOptionCard(
        id: String,
        title: String,
        subtitle: String,
        badge: String,
        badgeColor: Color,
        icon: String,
        iconGradient: [Color],
        bullets: [String],
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredCard == id

        VStack(alignment: .leading, spacing: 0) {
            // Top Badge & Icon
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                        .shadow(color: iconGradient.first?.opacity(0.4) ?? .clear, radius: 10, x: 0, y: 4)

                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text(badge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(badgeColor.opacity(0.2))
                    .foregroundColor(badgeColor)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(badgeColor.opacity(0.4), lineWidth: 0.8))
            }
            .padding(.bottom, 18)

            // Titles
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 4)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .padding(.bottom, 20)

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.bottom, 16)

            // Bullets
            VStack(alignment: .leading, spacing: 10) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(badgeColor)
                            .padding(.top, 2)

                        Text(bullet)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 16)

            // Huge Action Button
            Button(action: action) {
                HStack {
                    Spacer()
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: isHovered ? iconGradient : [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isHovered ? Color.white.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(28)
        .frame(width: 360, height: 390)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isHovered ? badgeColor.opacity(0.7) : Color.white.opacity(0.1), lineWidth: isHovered ? 1.5 : 1)
        )
        .shadow(color: isHovered ? badgeColor.opacity(0.25) : Color.black.opacity(0.4), radius: isHovered ? 20 : 10, x: 0, y: 8)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            hoveredCard = hovering ? id : nil
        }
    }
}
