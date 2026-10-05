import SwiftUI
import AppKit

struct AccountSetupView: View {
    var onComplete: () -> Void

    @ObservedObject private var accountManager = AccountManager.shared
    @ObservedObject private var addonManager = StremioAddonManager.shared
    @ObservedObject private var adManager = AdPlacementManager.shared

    @State private var isCreatingNewProfile: Bool = false
    @State private var step: Int = 1 // 1: Profile, 2: Preferences, 3: Add-ons, 4: Engine & Speed

    // Profile form state
    @State private var profileName: String = ""
    @State private var selectedIcon: String = "person.fill"
    @State private var selectedColor: String = "purple"
    @State private var preferredQuality: String = "4k"
    @State private var preferredLanguage: String = "en"

    // Engine choice (Classic vs Debrid)
    @State private var isDebridMode: Bool = false
    @State private var debridApiKeyInput: String = "" // Isolated per profile!
    @State private var isVerifyingDebrid: Bool = false
    @State private var debridStatusMessage: String? = nil

    // Addon install state in onboarding
    @State private var isInstallingCommunityPack: Bool = false
    @State private var hasInstalledCommunityPack: Bool = false
    @State private var customAddonUrlInput: String = ""
    @State private var addonInstallError: String? = nil

    var body: some View {
        ZStack {
            // Dark Cinema Acrylic Background
            Color(red: 0.05, green: 0.05, blue: 0.06)
                .ignoresSafeArea()

            // Dynamic Ambient Backlight
            RadialGradient(
                colors: [
                    AccountManager.colorForName(selectedColor).opacity(0.18),
                    Color.blue.opacity(0.06),
                    Color.clear
                ],
                center: .top,
                startRadius: 40,
                endRadius: 750
            )
            .ignoresSafeArea()

            if !isCreatingNewProfile && !accountManager.accounts.isEmpty {
                profileSwitcherScreen
            } else {
                profileCreationFlow
            }
        }
        .frame(minWidth: 880, idealWidth: 940, minHeight: 650, idealHeight: 720)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .onAppear {
            Task {
                await adManager.maybeShowAd(for: .setupScreen)
            }
        }
    }

    // MARK: - 1. Profile Switcher Screen ("Who's Watching?")
    private var profileSwitcherScreen: some View {
        VStack(spacing: 40) {
            // Logo & Title
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [Color.white, Color(white: 0.85)]),
                                center: .center,
                                startRadius: 2,
                                endRadius: 12
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: Color.white.opacity(0.5), radius: 8, x: 0, y: 0)
                }

                Text("Who's Watching?")
                    .font(.custom("Baskerville", size: 36))
                    .foregroundColor(.white)

                Text("Select your profile to continue with your personal watch history and preferences.")
                    .font(.custom("Helvetica", size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Profiles Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(accountManager.accounts) { account in
                        Button(action: {
                            onComplete()
                            accountManager.switchAccountWithTransition(account)
                        }) {
                            VStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(AccountManager.colorForName(account.avatarColor).opacity(0.25))
                                        .frame(width: 130, height: 130)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .stroke(AccountManager.colorForName(account.avatarColor).opacity(0.6), lineWidth: 2)
                                        )
                                        .shadow(color: AccountManager.colorForName(account.avatarColor).opacity(0.3), radius: 12, x: 0, y: 6)

                                    Image(systemName: account.avatarIcon)
                                        .font(.system(size: 48))
                                        .foregroundColor(AccountManager.colorForName(account.avatarColor))
                                }

                                VStack(spacing: 4) {
                                    Text(account.username)
                                        .font(.custom("Helvetica", size: 15).weight(.semibold))
                                        .foregroundColor(.white)

                                    Text(account.setupMode == "debrid" ? "Turbo Engine" : "Classic Engine")
                                        .font(.custom("Helvetica", size: 11))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Add Profile Card
                    Button(action: {
                        resetForm()
                        isCreatingNewProfile = true
                    }) {
                        VStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 2, dash: [6]))
                                    .frame(width: 130, height: 130)

                                Image(systemName: "plus")
                                    .font(.system(size: 38))
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Text("Add Profile")
                                .font(.custom("Helvetica", size: 14).weight(.medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 40)
            }
            .frame(height: 200)

            // Guest Quick Launch
            Button(action: {
                let guest = accountManager.createAccount(
                    username: "Guest",
                    avatarIcon: "person.crop.circle.badge.questionmark",
                    avatarColor: "cyan",
                    setupMode: "classic",
                    debridApiKey: nil,
                    isGuest: true
                )
                onComplete()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.badge.plus")
                    Text("Continue as Quick Guest")
                }
                .font(.custom("Helvetica", size: 13))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - 2. Profile Creation Wizard
    private var profileCreationFlow: some View {
        VStack(spacing: 24) {
            // Top Bar
            HStack {
                if !accountManager.accounts.isEmpty {
                    Button(action: {
                        isCreatingNewProfile = false
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back to Profiles")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
                // 4-Step Indicator
                HStack(spacing: 8) {
                    stepCircle(num: 1, title: "Profile")
                    Divider().frame(width: 20, height: 1).background(Color.white.opacity(0.2))
                    stepCircle(num: 2, title: "Preferences")
                    Divider().frame(width: 20, height: 1).background(Color.white.opacity(0.2))
                    stepCircle(num: 3, title: "Add-ons")
                    Divider().frame(width: 20, height: 1).background(Color.white.opacity(0.2))
                    stepCircle(num: 4, title: "Engine & Speed")
                }
                Spacer()
                Text("").frame(width: 80)
            }
            .padding(.horizontal, 36)
            .padding(.top, 20)

            // Step Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    if step == 1 {
                        step1IdentityView
                    } else if step == 2 {
                        step2PreferencesView
                    } else if step == 3 {
                        step3AddonsView
                    } else {
                        step4SpeedEngineView
                    }
                }
                .frame(maxWidth: 820)
                .padding(.horizontal, 10)
            }

            // Navigation Controls
            HStack(spacing: 16) {
                if step > 1 {
                    Button("Back") {
                        withAnimation { step -= 1 }
                    }
                    .font(.custom("Helvetica", size: 14).weight(.bold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                if step < 4 {
                    Button("Continue") {
                        withAnimation { step += 1 }
                    }
                    .font(.custom("Helvetica", size: 14).weight(.bold))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(profileName.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .buttonStyle(PlainButtonStyle())
                    .disabled(profileName.isEmpty)
                } else {
                    // Final Step (Speed Engine) Buttons
                    Button(action: finalizeAccountCreation) {
                        Text("Skip / Setup Later")
                            .font(.custom("Helvetica", size: 13))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: finalizeAccountCreation) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Complete & Enter Somnius")
                        }
                        .font(.custom("Helvetica", size: 14).weight(.bold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.purple.opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: 820)
            .padding(.horizontal, 36)

            // Non-Intrusive Sponsored Ad Banner (Requirement 3)
            if let ad = adManager.activeSetupAd, adManager.isAdsEnabled {
                AdBannerCardView(ad: ad, placement: .setupScreen) {
                    adManager.dismissAd(for: .setupScreen)
                }
                .frame(maxWidth: 820)
                .padding(.horizontal, 36)
                .padding(.bottom, 10)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Step 1: Identity (Name & Avatar)
    private var step1IdentityView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Create Your Somnius Profile")
                    .font(.custom("Baskerville", size: 28))
                    .foregroundColor(.white)
                Text("Customize your avatar and display name.")
                    .font(.custom("Helvetica", size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Big Live Avatar Preview
            ZStack {
                Circle()
                    .fill(AccountManager.colorForName(selectedColor).opacity(0.2))
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .stroke(AccountManager.colorForName(selectedColor), lineWidth: 3)
                    )
                    .shadow(color: AccountManager.colorForName(selectedColor).opacity(0.4), radius: 12, x: 0, y: 4)

                Image(systemName: selectedIcon)
                    .font(.system(size: 40))
                    .foregroundColor(AccountManager.colorForName(selectedColor))
            }

            // Profile Name Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Profile Name")
                    .font(.custom("Helvetica", size: 12).weight(.bold))
                    .foregroundColor(.white.opacity(0.8))

                TextField("Enter profile name...", text: $profileName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.custom("Helvetica", size: 15))
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .frame(maxWidth: 420)

            // Avatar Icon Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose Icon")
                    .font(.custom("Helvetica", size: 12).weight(.bold))
                    .foregroundColor(.white.opacity(0.8))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AccountManager.availableAvatarIcons, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle().stroke(selectedIcon == icon ? Color.white : Color.clear, lineWidth: 2)
                                        )

                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedIcon == icon ? .white : .white.opacity(0.6))
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: 420)

            // Accent Color Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Theme Color")
                    .font(.custom("Helvetica", size: 12).weight(.bold))
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 12) {
                    ForEach(AccountManager.availableAvatarColors, id: \.self) { colorName in
                        Button(action: { selectedColor = colorName }) {
                            Circle()
                                .fill(AccountManager.colorForName(colorName))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: selectedColor == colorName ? 3 : 0)
                                )
                                .scaleEffect(selectedColor == colorName ? 1.15 : 1.0)
                                .animation(.spring(response: 0.2), value: selectedColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(maxWidth: 420)
        }
    }

    // MARK: - Step 2: Preferences (Quality & Language)
    private var step2PreferencesView: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("Playback Preferences")
                    .font(.custom("Baskerville", size: 28))
                    .foregroundColor(.white)
                Text("Set your preferred resolution target and default subtitles.")
                    .font(.custom("Helvetica", size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            VStack(spacing: 20) {
                // Resolution Selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("Target Resolution Priority")
                        .font(.custom("Helvetica", size: 13).weight(.bold))
                        .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 12) {
                        qualityOption(title: "4K Ultra HD", subtitle: "2160p HDR / Dolby Vision", tag: "4k")
                        qualityOption(title: "1080p FHD", subtitle: "Full High Definition", tag: "1080p")
                        qualityOption(title: "720p HD", subtitle: "Bandwidth Saver", tag: "720p")
                    }
                }

                // Subtitle Language Selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("Preferred Subtitles")
                        .font(.custom("Helvetica", size: 13).weight(.bold))
                        .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 12) {
                        languageOption(name: "English", code: "en")
                        languageOption(name: "Turkish", code: "tr")
                        languageOption(name: "French", code: "fr")
                        languageOption(name: "German", code: "de")
                        languageOption(name: "Spanish", code: "es")
                    }
                }
            }
            .frame(maxWidth: 580)
        }
    }

    // MARK: - Step 3: Dedicated Community Add-ons Step
    private var step3AddonsView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Community Add-ons")
                    .font(.custom("Baskerville", size: 28))
                    .foregroundColor(.white)
                Text("Somnius is an agnostic media player shell. Community add-ons provide decentralized index searching.")
                    .font(.custom("Helvetica", size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            // Community Pack 1-Click Card
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Community Add-ons Pack")
                            .font(.custom("Helvetica", size: 15).weight(.bold))
                            .foregroundColor(.white)
                        Text("Torrentio, Zilean (KnightCrawler), Bitmagnet (MediaFusion), OpenSubtitles")
                            .font(.custom("Helvetica", size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    if hasInstalledCommunityPack || !addonManager.installedAddons.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ready")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                // Badges
                HStack(spacing: 8) {
                    addonBadge(name: "Torrentio", icon: "bolt.fill")
                    addonBadge(name: "Zilean", icon: "shield.fill")
                    addonBadge(name: "Bitmagnet", icon: "waveform.path.ecg")
                    addonBadge(name: "OpenSubtitles", icon: "captions.bubble.fill")
                }

                // 1-Click Install Button
                Button(action: {
                    Task {
                        isInstallingCommunityPack = true
                        await addonManager.installCommunityStreamingPack(debridKey: debridApiKeyInput)
                        isInstallingCommunityPack = false
                        hasInstalledCommunityPack = true
                    }
                }) {
                    HStack(spacing: 8) {
                        if isInstallingCommunityPack {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.black)
                            Text("Installing Community Add-ons...")
                        } else if hasInstalledCommunityPack || !addonManager.installedAddons.isEmpty {
                            Image(systemName: "arrow.clockwise")
                            Text("Reinstall / Update Community Add-ons")
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Install Community Add-ons Pack (1-Click)")
                        }
                    }
                    .font(.custom("Helvetica", size: 13).weight(.bold))
                    .foregroundColor((hasInstalledCommunityPack || !addonManager.installedAddons.isEmpty) ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background((hasInstalledCommunityPack || !addonManager.installedAddons.isEmpty) ? Color.white.opacity(0.12) : Color.white)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isInstallingCommunityPack)
            }
            .padding(18)
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.09), lineWidth: 1))

            // Custom Addon Manifest Link (Optional)
            DisclosureGroup("Add Custom Add-on URL (Manifest)") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("https://.../manifest.json", text: $customAddonUrlInput)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))
                            .padding(9)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))

                        Button("Install") {
                            let urlStr = customAddonUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard let url = URL(string: urlStr) else {
                                addonInstallError = "Invalid manifest URL"
                                return
                            }
                            Task {
                                do {
                                    _ = try await addonManager.installAddon(rawUrl: urlStr)
                                    customAddonUrlInput = ""
                                    addonInstallError = nil
                                    hasInstalledCommunityPack = true
                                } catch {
                                    addonInstallError = error.localizedDescription
                                }
                            }
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    if let err = addonInstallError {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                }
                .padding(.top, 8)
            }
            .font(.custom("Helvetica", size: 12))
            .foregroundColor(.white.opacity(0.7))
            .padding(14)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
        }
        .frame(maxWidth: 720)
    }

    // MARK: - Step 4: Engine Performance (Speed Choice)
    private var step4SpeedEngineView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Choose Engine Performance")
                    .font(.custom("Baskerville", size: 28))
                    .foregroundColor(.white)
                Text("Select your preferred delivery engine for this profile. You can change this anytime.")
                    .font(.custom("Helvetica", size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Two Choice Big Step
            HStack(alignment: .top, spacing: 16) {
                // Choice 1: Classic Speed (Standard Engine)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDebridMode = false
                    }
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "network")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Text("Standard Speed")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white.opacity(0.7))
                                .clipShape(Capsule())
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Classic Engine")
                                .font(.custom("Helvetica", size: 16).weight(.bold))
                                .foregroundColor(.white)
                            Text("Decentralized Peer Swarm")
                                .font(.custom("Helvetica", size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            bulletItem("Zero accounts or tokens required")
                            bulletItem("Direct peer-to-peer distribution")
                            bulletItem("Throughput scales with peer seeders")
                        }
                        .padding(.top, 4)

                        Spacer()

                        HStack {
                            Text(!isDebridMode ? "✓ Selected Engine" : "Select Classic")
                                .font(.caption.bold())
                                .foregroundColor(!isDebridMode ? .green : .white.opacity(0.6))
                            Spacer()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 210)
                    .background(!isDebridMode ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(!isDebridMode ? Color.white.opacity(0.4) : Color.white.opacity(0.08), lineWidth: !isDebridMode ? 2 : 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Choice 2: Turbo Speed (Debrid Engine)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDebridMode = true
                    }
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.18, green: 0.8, blue: 0.55).opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.22, green: 0.82, blue: 0.6))
                            }
                            Spacer()
                            Text("1 Gbps Lightning")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(red: 0.18, green: 0.8, blue: 0.55).opacity(0.18))
                                .foregroundColor(Color(red: 0.25, green: 0.88, blue: 0.65))
                                .clipShape(Capsule())
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Turbo Engine")
                                .font(.custom("Helvetica", size: 16).weight(.bold))
                                .foregroundColor(.white)
                            Text("Instant Cached Cloud Line")
                                .font(.custom("Helvetica", size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            bulletItem("Instant 4K UHD Remux & Dolby Vision")
                            bulletItem("Uncapped 1 Gbps direct pipe (no buffering)")
                            bulletItem("Instant seek without waiting for peers")
                        }
                        .padding(.top, 4)

                        Spacer()

                        HStack {
                            Text(isDebridMode ? "✓ Selected Engine" : "Select Turbo")
                                .font(.caption.bold())
                                .foregroundColor(isDebridMode ? Color(red: 0.22, green: 0.82, blue: 0.6) : .white.opacity(0.6))
                            Spacer()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 210)
                    .background(isDebridMode ? Color(red: 0.18, green: 0.8, blue: 0.55).opacity(0.08) : Color.white.opacity(0.03))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isDebridMode ? Color(red: 0.18, green: 0.8, blue: 0.55).opacity(0.6) : Color.white.opacity(0.08), lineWidth: isDebridMode ? 2 : 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // If Turbo Engine is selected, show Token Input & Affiliate Banner
            if isDebridMode {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connect Debrid Token (for \(profileName.isEmpty ? "this profile" : profileName))")
                            .font(.custom("Helvetica", size: 13).weight(.bold))
                            .foregroundColor(.white)
                        Text("Enter your API key below. Each profile in Somnius can have its own separate account.")
                            .font(.custom("Helvetica", size: 11))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    HStack(spacing: 8) {
                        SecureField("Paste Real-Debrid API Key...", text: $debridApiKeyInput)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))

                        if let clipboard = NSPasteboard.general.string(forType: .string), !clipboard.isEmpty {
                            Button("Paste") {
                                debridApiKeyInput = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .buttonStyle(PlainButtonStyle())
                        }

                        Button(action: verifyAndApplyDebridKey) {
                            HStack(spacing: 4) {
                                if isVerifyingDebrid {
                                    ProgressView().scaleEffect(0.6)
                                }
                                Text("Connect")
                            }
                            .font(.custom("Helvetica", size: 12).weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(debridApiKeyInput.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(debridApiKeyInput.isEmpty || isVerifyingDebrid)
                    }

                    if let msg = debridStatusMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(msg.contains("✓") ? .green : (msg.contains("⚠️") ? .yellow : .red))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Authentic Real-Debrid Affiliate Banner & Partner Card (ID: 10141263)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.18, green: 0.8, blue: 0.55),
                                                Color(red: 0.12, green: 0.65, blue: 0.95),
                                                Color(red: 0.18, green: 0.8, blue: 0.55)
                                            ]),
                                            center: .center
                                        ),
                                        lineWidth: 3
                                    )
                                    .frame(width: 32, height: 32)
                                Circle()
                                    .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                                    .frame(width: 18, height: 18)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    HStack(spacing: 0) {
                                        Text("Real").font(.custom("Helvetica", size: 14).weight(.bold)).foregroundColor(.white)
                                        Text("Debrid").font(.custom("Helvetica", size: 14).weight(.black)).foregroundColor(Color(red: 0.22, green: 0.82, blue: 0.6))
                                    }
                                    Text("HIGH-SPEED CLOUD CACHE")
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 0.18, green: 0.8, blue: 0.55).opacity(0.18))
                                        .foregroundColor(Color(red: 0.25, green: 0.88, blue: 0.65))
                                        .clipShape(Capsule())
                                }

                                Text("Get instant 1Gbps cloud caching, 4K UHD Remux, Dolby Vision & eliminate all buffering.")
                                    .font(.custom("Helvetica", size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()

                            Button(action: {
                                NSWorkspace.shared.open(Config.realDebridAffiliateUrl)
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "bolt.fill").font(.system(size: 10))
                                    Text("Get Real-Debrid")
                                    Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .bold))
                                }
                                .font(.custom("Helvetica", size: 11).weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.18, green: 0.8, blue: 0.55), Color(red: 0.1, green: 0.62, blue: 0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.black)
                                .cornerRadius(7)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Divider().background(Color.white.opacity(0.08))

                        HStack {
                            Text("Starting at ~$3/mo • 1 Gbps Cloud Bandwidth")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Button(action: {
                                NSWorkspace.shared.open(Config.realDebridApiTokenUrl)
                            }) {
                                HStack(spacing: 3) {
                                    Text("Find your API Token")
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.cyan)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(12)
                    .background(Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.55))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.18, green: 0.8, blue: 0.55).opacity(0.2), lineWidth: 1))
                }
                .padding(16)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
        }
        .frame(maxWidth: 780)
    }

    private func bulletItem(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .foregroundColor(.white.opacity(0.4))
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.65))
        }
    }

    private func qualityOption(title: String, subtitle: String, tag: String) -> some View {
        Button(action: { preferredQuality = tag }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.custom("Helvetica", size: 14).weight(.bold))
                    .foregroundColor(preferredQuality == tag ? .white : .white.opacity(0.7))
                Text(subtitle)
                    .font(.custom("Helvetica", size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(preferredQuality == tag ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(preferredQuality == tag ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func languageOption(name: String, code: String) -> some View {
        Button(action: { preferredLanguage = code }) {
            Text(name)
                .font(.custom("Helvetica", size: 12).weight(.medium))
                .foregroundColor(preferredLanguage == code ? .white : .white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(preferredLanguage == code ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(preferredLanguage == code ? Color.blue : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func addonBadge(name: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private func verifyAndApplyDebridKey() {
        let clean = debridApiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        isVerifyingDebrid = true
        debridStatusMessage = nil

        Task {
            Config.realDebridApiKey = clean
            let service = RealDebridService()
            do {
                let user = try await service.fetchUser()
                isVerifyingDebrid = false
                debridStatusMessage = "✓ Connected as \(user.username) (\(user.type.capitalized))"
                await addonManager.updateDebridForInstalledAddons(debridKey: clean)
                hasInstalledCommunityPack = true
            } catch {
                isVerifyingDebrid = false
                let desc = error.localizedDescription
                let nsError = error as NSError
                // Detect TLS / DPI ISP interception (common with local ISPs blocking api.real-debrid.com)
                if desc.localizedCaseInsensitiveContains("TLS") || desc.localizedCaseInsensitiveContains("secure connection") || nsError.code == NSURLErrorSecureConnectionFailed {
                    debridStatusMessage = "⚠️ ISP Block Detected: Your internet provider is blocking direct access to api.real-debrid.com. Please connect to a VPN or Cloudflare WARP. (Your token was saved to streaming add-ons anyway!)"
                    await addonManager.updateDebridForInstalledAddons(debridKey: clean)
                    hasInstalledCommunityPack = true
                } else {
                    debridStatusMessage = "Connection failed: \(desc)"
                }
            }
        }
    }

    private func stepCircle(num: Int, title: String) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(step >= num ? Color.blue : Color.white.opacity(0.1))
                    .frame(width: 22, height: 22)
                Text("\(num)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(step >= num ? .white : .white.opacity(0.5))
        }
    }

    private func finalizeAccountCreation() {
        // Auto-install community pack if not yet installed
        let cleanDebrid = isDebridMode ? debridApiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        if addonManager.installedAddons.isEmpty {
            Task {
                await addonManager.installCommunityStreamingPack(debridKey: cleanDebrid)
            }
        }

        let mode = (!cleanDebrid.isEmpty && isDebridMode) ? "debrid" : "classic"

        _ = accountManager.createAccount(
            username: profileName.isEmpty ? "Somnius User" : profileName,
            avatarIcon: selectedIcon,
            avatarColor: selectedColor,
            setupMode: mode,
            debridApiKey: !cleanDebrid.isEmpty ? cleanDebrid : nil,
            preferredQuality: preferredQuality,
            preferredLanguage: preferredLanguage,
            isGuest: false
        )
        onComplete()
    }

    private func resetForm() {
        step = 1
        profileName = ""
        selectedIcon = "person.fill"
        selectedColor = "purple"
        preferredQuality = "4k"
        preferredLanguage = "en"
        isDebridMode = false
        debridApiKeyInput = "" // Isolated per profile!
        debridStatusMessage = nil
    }
}
