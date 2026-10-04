import SwiftUI
import AppKit

struct AccountSetupView: View {
    var onComplete: () -> Void

    @ObservedObject private var accountManager = AccountManager.shared
    @State private var isCreatingNewProfile: Bool = false
    @State private var step: Int = 1 // 1: Identity, 2: Streaming Engine Decision, 3: Playback Preferences

    // Profile form state
    @State private var profileName: String = ""
    @State private var selectedIcon: String = "person.fill"
    @State private var selectedColor: String = "purple"
    @State private var selectedMode: String = "debrid" // "debrid" vs "classic"
    @State private var debridApiKeyInput: String = ""
    @State private var preferredQuality: String = "4k"
    @State private var preferredLanguage: String = "en"

    // Verification state
    @State private var isTestingKey: Bool = false
    @State private var keyTestSuccessMessage: String?
    @State private var keyTestErrorMessage: String?

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
        .frame(minWidth: 950, minHeight: 650)
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
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }

            // Profiles Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(accountManager.accounts) { account in
                        Button(action: {
                            accountManager.selectAccount(account)
                            onComplete()
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
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.white)

                                    Text(account.setupMode == "debrid" ? "Real-Debrid" : "Classic P2P")
                                        .font(.caption2)
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
                                .font(.headline.weight(.medium))
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
                accountManager.selectAccount(guest)
                onComplete()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.badge.plus")
                    Text("Continue as Quick Guest")
                }
                .font(.subheadline)
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
                    stepCircle(num: 2, title: "Streaming Engine")
                    Divider().frame(width: 24, height: 1).background(Color.white.opacity(0.2))
                    stepCircle(num: 3, title: "Preferences")
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
                    step2EngineDecisionView
                } else {
                    step3PreferencesView
                }
            }
            .frame(maxWidth: 720)

            // Navigation Controls
            HStack(spacing: 16) {
                if step > 1 {
                    Button("Back") {
                        withAnimation { step -= 1 }
                    }
                    .font(.subheadline.bold())
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
                    .font(.subheadline.bold())
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(profileName.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .buttonStyle(PlainButtonStyle())
                    .disabled(profileName.isEmpty)
                } else {
                    Button(action: finalizeAccountCreation) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Launch Somnius")
                        }
                        .font(.headline.bold())
                        .padding(.horizontal, 32)
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
            .frame(maxWidth: 720)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 1: Identity (Name & Avatar)
    private var step1IdentityView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Create Your Somnius Profile")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Customize your avatar and display name.")
                    .font(.subheadline)
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
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))

                TextField("e.g. Umut, Cinema Room, Living Room", text: $profileName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 15))
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }

            // Avatar Icon Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose Avatar Icon")
                    .font(.caption.bold())
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
                    .font(.caption.bold())
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

    // MARK: - Step 2: Streaming Engine Decision
    private var step2EngineDecisionView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Choose How You Want to Stream")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Select your streaming engine. Somnius is an agnostic player shell.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }

            HStack(spacing: 20) {
                // Option 1: Debrid Cloud CDN
                Button(action: { selectedMode = "debrid" }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "bolt.shield.fill")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                            }
                            Spacer()
                            if selectedMode == "debrid" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                            }
                        }

                        Text("Real-Debrid Cloud CDN")
                            .font(.headline.bold())
                            .foregroundColor(.white)

                        Text("Encrypted multi-gigabit streaming for massive 4K Remuxes & Dolby Atmos. Zero peer seeding or IP exposure.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(3)

                        Text("Recommended for 4K UHD")
                            .font(.caption2.bold())
                            .foregroundColor(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .padding(18)
                    .frame(height: 190)
                    .background(Color.white.opacity(selectedMode == "debrid" ? 0.08 : 0.03))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selectedMode == "debrid" ? Color.purple : Color.white.opacity(0.08), lineWidth: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Option 2: Classic Free P2P
                Button(action: { selectedMode = "classic" }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                            Spacer()
                            if selectedMode == "classic" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                        }

                        Text("Classic Free Streaming")
                            .font(.headline.bold())
                            .foregroundColor(.white)

                        Text("Direct fast streaming from verified peers. Completely free with zero accounts or subscriptions required.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(3)

                        Text("No Account Needed")
                            .font(.caption2.bold())
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .padding(18)
                    .frame(height: 190)
                    .background(Color.white.opacity(selectedMode == "classic" ? 0.08 : 0.03))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selectedMode == "classic" ? Color.blue : Color.white.opacity(0.08), lineWidth: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Real-Debrid API Key Input if Debrid Selected
            if selectedMode == "debrid" {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Enter Real-Debrid API Key")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Link("Get Key from Real-Debrid ↗", destination: URL(string: "https://real-debrid.com/apitoken")!)
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }

                    HStack(spacing: 10) {
                        SecureField("Paste API Token here", text: $debridApiKeyInput)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 13, design: .monospaced))
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))

                        Button(action: verifyRealDebridKey) {
                            HStack(spacing: 5) {
                                if isTestingKey {
                                    ProgressView().scaleEffect(0.6)
                                }
                                Text("Test Key")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(debridApiKeyInput.isEmpty || isTestingKey)
                    }

                    if let succ = keyTestSuccessMessage {
                        Text(succ)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if let err = keyTestErrorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Step 3: Preferences View
    private var step3PreferencesView: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("Set Playback Preferences")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("You can change these anytime in Settings.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 14) {
                // Preferred Quality
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preferred Quality")
                        .font(.caption.bold())
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
                        .font(.caption.bold())
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

    private func verifyRealDebridKey() {
        let key = debridApiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        isTestingKey = true
        keyTestSuccessMessage = nil
        keyTestErrorMessage = nil

        Task {
            guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/user") else { return }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            req.timeoutInterval = 5.0

            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    struct RDUser: Decodable {
                        let username: String
                        let type: String
                    }
                    if let user = try? JSONDecoder().decode(RDUser.self, from: data) {
                        await MainActor.run {
                            keyTestSuccessMessage = "✓ Verified: Welcome \(user.username) (\(user.type.capitalized))"
                            isTestingKey = false
                        }
                        return
                    }
                }
                await MainActor.run {
                    keyTestErrorMessage = "Invalid Real-Debrid API Key."
                    isTestingKey = false
                }
            } catch {
                await MainActor.run {
                    keyTestErrorMessage = "Connection error: \(error.localizedDescription)"
                    isTestingKey = false
                }
            }
        }
    }

    private func finalizeAccountCreation() {
        let account = accountManager.createAccount(
            username: profileName,
            avatarIcon: selectedIcon,
            avatarColor: selectedColor,
            setupMode: selectedMode,
            debridApiKey: selectedMode == "debrid" ? debridApiKeyInput : nil,
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
        selectedMode = "debrid"
        debridApiKeyInput = ""
        keyTestSuccessMessage = nil
        keyTestErrorMessage = nil
    }
}
