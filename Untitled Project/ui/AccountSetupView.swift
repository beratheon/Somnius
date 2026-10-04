import SwiftUI
import AppKit

struct AccountSetupView: View {
    var onComplete: () -> Void

    @ObservedObject private var accountManager = AccountManager.shared
    @ObservedObject private var addonManager = StremioAddonManager.shared
    @State private var isCreatingNewProfile: Bool = false
    @State private var step: Int = 1 // 1: Profile, 2: Preferences, 3: Add-ons (Optional)

    // Profile form state
    @State private var profileName: String = ""
    @State private var selectedIcon: String = "person.fill"
    @State private var selectedColor: String = "purple"
    @State private var preferredQuality: String = "4k"
    @State private var preferredLanguage: String = "en"

    // Addon install state in onboarding
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
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

                                    Text("Personal Profile")
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
                accountManager.switchAccountWithTransition(guest)
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
        VStack(spacing: 28) {
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
                // Step Indicator
                HStack(spacing: 8) {
                    stepCircle(num: 1, title: "Profile")
                    Divider().frame(width: 24, height: 1).background(Color.white.opacity(0.2))
                    stepCircle(num: 2, title: "Preferences")
                    Divider().frame(width: 24, height: 1).background(Color.white.opacity(0.2))
                    stepCircle(num: 3, title: "Add-ons")
                }
                Spacer()
                // Placeholder to balance HStack
                Text("").frame(width: 80)
            }
            .padding(.horizontal, 36)
            .padding(.top, 24)

            // Step Content
            VStack(spacing: 24) {
                if step == 1 {
                    step1IdentityView
                } else if step == 2 {
                    step2PreferencesView
                } else {
                    step3AddonsView
                }
            }
            .frame(maxWidth: 760)

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

                if step < 3 {
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
                    // Optional Add-ons step - Clear choices
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
                            Text("Complete & Launch Somnius")
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
            .frame(maxWidth: 760)
            .padding(.bottom, 24)
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
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(AccountManager.colorForName(selectedColor), lineWidth: 3)
                    )
                    .shadow(color: AccountManager.colorForName(selectedColor).opacity(0.4), radius: 12, x: 0, y: 4)

                Image(systemName: selectedIcon)
                    .font(.system(size: 42))
                    .foregroundColor(AccountManager.colorForName(selectedColor))
            }

            // Profile Name Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Profile Name")
                    .font(.custom("Helvetica", size: 12).weight(.bold))
                    .foregroundColor(.white.opacity(0.8))

                TextField("e.g. Umut, Cinema Room, Living Room", text: $profileName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.custom("Helvetica", size: 15))
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }

            // Avatar Icon Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose Avatar Icon")
                    .font(.custom("Helvetica", size: 12).weight(.bold))
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 12) {
                    ForEach(AccountManager.availableAvatarIcons, id: \.self) { icon in
                        Button(action: { selectedIcon = icon }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedIcon == icon ? Color.white.opacity(0.2) : Color.white.opacity(0.04))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedIcon == icon ? Color.white : Color.clear, lineWidth: 1.5)
                                    )

                                Image(systemName: icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // Avatar Color Palette
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose Theme Color")
                    .font(.custom("Helvetica", size: 12).weight(.bold))
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 14) {
                    ForEach(AccountManager.availableAvatarColors, id: \.self) { colorName in
                        Button(action: { selectedColor = colorName }) {
                            ZStack {
                                Circle()
                                    .fill(AccountManager.colorForName(colorName))
                                    .frame(width: 30, height: 30)

                                if selectedColor == colorName {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 36, height: 36)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Preferences View
    private var step2PreferencesView: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("Set Playback Preferences")
                    .font(.custom("Baskerville", size: 28))
                    .foregroundColor(.white)
                Text("You can change these anytime in Settings.")
                    .font(.custom("Helvetica", size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 14) {
                // Preferred Quality
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preferred Quality")
                        .font(.custom("Helvetica", size: 12).weight(.bold))
                        .foregroundColor(.white.opacity(0.8))

                    Picker("", selection: $preferredQuality) {
                        Text("4K UHD Remux (Best)").tag("4k")
                        Text("1080p FHD (Balanced)").tag("1080p")
                        Text("720p HD (Low Bandwidth)").tag("720p")
                    }
                    .pickerStyle(.segmented)
                }

                // Preferred Subtitle Language
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default Subtitle & Audio Language")
                        .font(.custom("Helvetica", size: 12).weight(.bold))
                        .foregroundColor(.white.opacity(0.8))

                    Picker("", selection: $preferredLanguage) {
                        Text("English (en)").tag("en")
                        Text("Turkish (tr)").tag("tr")
                        Text("German (de)").tag("de")
                        Text("French (fr)").tag("fr")
                        Text("Spanish (es)").tag("es")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)
        }
    }

    // MARK: - Step 3: Add-ons (Optional)
    private var step3AddonsView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("Add-on Installation")
                        .font(.custom("Baskerville", size: 28))
                        .foregroundColor(.white)
                    Text("Optional")
                        .font(.custom("Helvetica", size: 11).weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.cyan.opacity(0.18))
                        .foregroundColor(.cyan)
                        .cornerRadius(6)
                }

                Text("Somnius is an agnostic media player. Add-ons allow external community indexing.")
                    .font(.custom("Helvetica", size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Legal notice with GitHub Repository Link
            HStack(spacing: 14) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.cyan)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Zero scrapers or tracking code are bundled in this application.")
                        .font(.custom("Helvetica", size: 13).weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                    Text("You can run Somnius purely as a local video player, or connect community add-ons from GitHub.")
                        .font(.custom("Helvetica", size: 12))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                Link(destination: URL(string: "https://github.com/beratheon/Somnius")!) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Browse Add-ons on GitHub ↗")
                    }
                    .font(.custom("Helvetica", size: 12).weight(.semibold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(8)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))

            // Official Add-on Card
            VStack(alignment: .leading, spacing: 12) {
                Text("Recommended Community Add-on")
                    .font(.custom("Baskerville", size: 18))
                    .foregroundColor(.white)

                let isOfficialInstalled = addonManager.installedAddons.contains(where: { $0.id == "community.somnius.official" })
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: "sparkles.tv")
                            .font(.system(size: 20))
                            .foregroundColor(.purple)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Somnius Official Add-on")
                                .font(.custom("Helvetica", size: 15).weight(.semibold))
                                .foregroundColor(.white)
                            Text("Open Source")
                                .font(.custom("Helvetica", size: 10).weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Text("Curated stream indexing engine maintained on GitHub (beratheon/Somnius).")
                            .font(.custom("Helvetica", size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            try? await addonManager.installAddon(rawUrl: "https://raw.githubusercontent.com/beratheon/Somnius/main/addon-repository/manifest.json")
                        }
                    }) {
                        Text(isOfficialInstalled ? "✓ Installed" : "Install Add-on")
                            .font(.custom("Helvetica", size: 12).weight(.bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isOfficialInstalled ? Color.white.opacity(0.1) : Color.blue)
                            .foregroundColor(isOfficialInstalled ? .gray : .white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isOfficialInstalled)
                }
                .padding(16)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
            }

            // Custom Add-on URL Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Or Install via Manifest URL")
                    .font(.custom("Baskerville", size: 16))
                    .foregroundColor(.white.opacity(0.85))

                HStack(spacing: 10) {
                    TextField("Enter manifest.json URL", text: $customAddonUrlInput)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13, design: .monospaced))
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))

                    Button(action: {
                        guard !customAddonUrlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        addonInstallError = nil
                        Task {
                            do {
                                _ = try await addonManager.installAddon(rawUrl: customAddonUrlInput)
                                customAddonUrlInput = ""
                            } catch {
                                addonInstallError = error.localizedDescription
                            }
                        }
                    }) {
                        HStack(spacing: 5) {
                            if addonManager.isInstalling {
                                ProgressView().scaleEffect(0.6)
                            }
                            Text("Install")
                        }
                        .font(.custom("Helvetica", size: 13).weight(.bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(addonManager.isInstalling || customAddonUrlInput.isEmpty)
                }

                if let err = addonInstallError {
                    Text(err)
                        .font(.custom("Helvetica", size: 12))
                        .foregroundColor(.red)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
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
        let account = accountManager.createAccount(
            username: profileName,
            avatarIcon: selectedIcon,
            avatarColor: selectedColor,
            setupMode: "classic",
            debridApiKey: nil,
            preferredQuality: preferredQuality,
            preferredLanguage: preferredLanguage,
            isGuest: false
        )
        accountManager.selectAccount(account)
        onComplete()
    }

    private func resetForm() {
        step = 1
        profileName = ""
        selectedIcon = "person.fill"
        selectedColor = "purple"
    }
}
