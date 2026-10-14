import SwiftUI

// MARK: - Catalog Studio View (Letterboxd, TMDB, Category Mixer & Gemini AI)
struct CatalogStudioView: View {
    @Binding var isPresented: Bool
    var initialTab: Int = 0

    @State private var selectedTab: Int = 0
    @ObservedObject private var liveCatalogService = LiveCatalogService.shared
    @ObservedObject private var discoveryService = CatalogDiscoveryService.shared
    @ObservedObject private var geminiService = GeminiCatalogService.shared

    @State private var addedNotice: String? = nil

    // MARK: - 1. Presets State
    @State private var presetFilterCategory: String = "All"
    @State private var presetSearchQuery: String = ""

    // MARK: - 2. Mixer State
    @State private var selectedGenres: Set<Int> = [878, 28] // Default Sci-Fi + Action
    @State private var mixerKeyword: String = ""
    @State private var selectedDecadeId: String = "all"
    @State private var mixerMediaType: String = "movie"
    @State private var mixerSortBy: String = "popularity.desc"
    @State private var mixerCustomTitle: String = ""
    @State private var isMixing: Bool = false
    @State private var mixedResults: [MediaItem] = []
    @State private var hasGeneratedMix: Bool = false

    // MARK: - 3. Gemini AI State
    @State private var geminiPrompt: String = ""
    @State private var geminiApiKeyInput: String = Config.geminiApiKey
    @State private var showApiKeySettings: Bool = false
    @State private var aiGeneratedCatalog: LiveCatalog? = nil
    @State private var aiErrorMessage: String? = nil

    // MARK: - 4. Custom Manifest State
    @State private var customName: String = ""
    @State private var customType: String = "movie"
    @State private var customCategory: String = "Custom Discovery"
    @State private var customEndpoint: String = ""

    private let presetCategories = [
        "All",
        "Letterboxd & Acclaimed",
        "Studios & Vaults",
        "Cult & Thrillers",
        "TMDB Live",
        "Streaming & TV",
        "Decades & World Cinema"
    ]

    private let promptIdeas = [
        "Atmospheric rainy neo-noir with synth music",
        "Mind-bending 90s psychological thrillers",
        "Deep space horror where crew wakes up from cryo",
        "Cozy autumn Ghibli-esque fantasy adventure",
        "High-stakes bank heist thrillers with clever twists",
        "A24 elevated folk horror and pagan folklore",
        "Cyberpunk detective stories set in Tokyo or LA",
        "Time travel paradoxes and infinite loops"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            // Main Studio Navigation Tabs
            tabBar

            Divider().background(Color.white.opacity(0.1))

            // Active Notice Banner
            if let notice = addedNotice {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(notice)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { addedNotice = nil }) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.18))
                .transition(.opacity)
            }

            // Tab Content Body
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    switch selectedTab {
                    case 0:
                        curatedVaultsTab
                    case 1:
                        categoryMixerTab
                    case 2:
                        geminiAITab
                    case 3:
                        customManifestTab
                    default:
                        curatedVaultsTab
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 880, idealWidth: 940, minHeight: 640, idealHeight: 720)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        .preferredColorScheme(.dark)
        .onAppear {
            self.selectedTab = initialTab
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title3)
                        .foregroundColor(SoftTone.mist.color)
                    Text("Discovery Catalog Studio")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                Text("Expand your home feed with Letterboxd masterpieces, TMDB hubs, keyword mixes, or Gemini AI.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 12) {
            tabButton(title: "Letterboxd & TMDB Lists", icon: "star.fill", index: 0, tagText: "\(discoveryService.curatedPresets.count)")
            tabButton(title: "Keyword & Category Mixer", icon: "slider.horizontal.3", index: 1, tagText: "Live")
            tabButton(title: "Ask Gemini AI", icon: "sparkles", index: 2, tagText: "AI", isSpecial: true)
            tabButton(title: "Custom Manifest", icon: "link", index: 3)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private func tabButton(title: String, icon: String, index: Int, tagText: String? = nil, isSpecial: Bool = false) -> some View {
        let isSelected = selectedTab == index
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                if let tag = tagText {
                    Text(tag)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSpecial ? Color.purple.opacity(0.4) : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? (isSpecial ? Color.purple.opacity(0.3) : SoftTone.mist.color.opacity(0.2)) : Color.white.opacity(0.05))
            .foregroundColor(isSelected ? (isSpecial ? Color.pink.opacity(0.9) : SoftTone.mist.color) : .white.opacity(0.75))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? (isSpecial ? Color.pink.opacity(0.5) : SoftTone.mist.color.opacity(0.4)) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - TAB 0: Curated Letterboxd & TMDB Vaults
    private var curatedVaultsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Search and Category Filter Row
            HStack(spacing: 12) {
                // Search Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Filter lists (e.g. A24, Criterion, Ghibli, 90s, Horror)...", text: $presetSearchQuery)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                    if !presetSearchQuery.isEmpty {
                        Button(action: { presetSearchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                .frame(maxWidth: 320)

                Spacer()

                // Preset Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presetCategories, id: \.self) { cat in
                            let isSel = presetFilterCategory == cat
                            Button(action: { presetFilterCategory = cat }) {
                                Text(cat)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSel ? SoftTone.lavender.color.opacity(0.25) : Color.white.opacity(0.05))
                                    .foregroundColor(isSel ? SoftTone.lavender.color : .white.opacity(0.7))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(isSel ? SoftTone.lavender.color.opacity(0.4) : Color.clear, lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Presets Grid
            let filteredPresets = discoveryService.curatedPresets.filter { preset in
                let matchesCategory = (presetFilterCategory == "All") || (preset.category == presetFilterCategory)
                let matchesQuery = presetSearchQuery.isEmpty ||
                    preset.title.localizedCaseInsensitiveContains(presetSearchQuery) ||
                    preset.subtitle.localizedCaseInsensitiveContains(presetSearchQuery) ||
                    preset.source.localizedCaseInsensitiveContains(presetSearchQuery) ||
                    preset.sampleTitles.contains(where: { $0.localizedCaseInsensitiveContains(presetSearchQuery) })
                return matchesCategory && matchesQuery
            }

            Text("Browse \(filteredPresets.count) acclaimed Letterboxd and TMDB curated lists. Toggle to add them directly to your discovery feed:")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(filteredPresets) { preset in
                    presetCard(preset: preset)
                }
            }
        }
    }

    private func presetCard(preset: CuratedCatalogPreset) -> some View {
        let isAlreadyAdded = liveCatalogService.catalogs.contains(where: { $0.id == preset.id || $0.name == preset.title })

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // Preset Icon Box
                Image(systemName: preset.icon)
                    .font(.title2)
                    .foregroundColor(preset.source == "A24" ? SoftTone.rose.color : (preset.source == "Criterion" ? SoftTone.sand.color : SoftTone.mist.color))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(preset.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer()

                        // Source Badge
                        Text(preset.source)
                            .font(.system(size: 10, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(preset.source == "Letterboxd" ? Color.green.opacity(0.2) : (preset.source == "TMDB" ? Color.blue.opacity(0.2) : Color.white.opacity(0.1)))
                            .foregroundColor(preset.source == "Letterboxd" ? .green : (preset.source == "TMDB" ? Color(red: 0.05, green: 0.71, blue: 0.83) : .white.opacity(0.8)))
                            .cornerRadius(4)
                    }

                    Text(preset.subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Sample film tags
            if !preset.sampleTitles.isEmpty {
                HStack(spacing: 5) {
                    ForEach(preset.sampleTitles.prefix(3), id: \.self) { title in
                        Text(title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(4)
                            .lineLimit(1)
                    }
                    if preset.sampleTitles.count > 3 {
                        Text("+\(preset.sampleTitles.count - 3)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
            }

            HStack {
                Text(preset.type == "series" ? "TV Series Catalog" : "Feature Film Catalog")
                    .font(.caption2)
                    .foregroundColor(.gray)

                Spacer()

                Button(action: {
                    Task {
                        let newCat = await discoveryService.activatePreset(preset)
                        liveCatalogService.addCatalog(newCat)
                        withAnimation {
                            addedNotice = "✓ Added \(preset.title) to your discovery feed!"
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isAlreadyAdded ? "checkmark" : "plus")
                        Text(isAlreadyAdded ? "Added to Home" : "Add to Home")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isAlreadyAdded ? Color.white.opacity(0.08) : SoftTone.mist.color.opacity(0.18))
                    .foregroundColor(isAlreadyAdded ? .gray : SoftTone.mist.color)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(isAlreadyAdded ? Color.clear : SoftTone.mist.color.opacity(0.35), lineWidth: 0.8))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isAlreadyAdded)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.035))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - TAB 1: Keyword & Category Mixer
    private var categoryMixerTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mix & Match Custom Categories")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text("Select multiple genres, combine with keywords or decades, and preview live results from TMDB.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            // 1. Select Multiple Genres
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Select Genres to Combine")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("(\(selectedGenres.count) selected)")
                        .font(.caption)
                        .foregroundColor(SoftTone.mist.color)
                    Spacer()
                    if !selectedGenres.isEmpty {
                        Button("Clear") { selectedGenres.removeAll() }
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)], spacing: 8) {
                    ForEach(discoveryService.availableGenres) { genre in
                        let isSelected = selectedGenres.contains(genre.id)
                        Button(action: {
                            if isSelected {
                                selectedGenres.remove(genre.id)
                            } else {
                                selectedGenres.insert(genre.id)
                            }
                            updateSuggestedTitle()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: genre.icon)
                                    .font(.system(size: 11))
                                Text(genre.name)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(isSelected ? SoftTone.lavender.color.opacity(0.28) : Color.white.opacity(0.05))
                            .foregroundColor(isSelected ? SoftTone.lavender.color : .white.opacity(0.75))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? SoftTone.lavender.color.opacity(0.45) : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 2. Keyword Filter & Suggestions
            VStack(alignment: .leading, spacing: 8) {
                Text("Search by Keyword or Theme (Optional)")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .foregroundColor(SoftTone.sand.color)
                    TextField("e.g. time loop, cyberpunk, heist, space, revenge...", text: $mixerKeyword)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .onChange(of: mixerKeyword) { _, _ in updateSuggestedTitle() }
                    if !mixerKeyword.isEmpty {
                        Button(action: {
                            mixerKeyword = ""
                            updateSuggestedTitle()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)

                // Quick Suggestion Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(discoveryService.keywordChips) { chip in
                            Button(action: {
                                mixerKeyword = chip.label
                                updateSuggestedTitle()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: chip.icon)
                                        .font(.system(size: 10))
                                    Text(chip.label)
                                        .font(.caption2.bold())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(mixerKeyword.lowercased() == chip.label.lowercased() ? SoftTone.sand.color.opacity(0.25) : Color.white.opacity(0.04))
                                .foregroundColor(mixerKeyword.lowercased() == chip.label.lowercased() ? SoftTone.sand.color : .white.opacity(0.65))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // 3. Decade & Media Type & Sort
            HStack(spacing: 16) {
                // Decade Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Era / Decade")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    Picker("", selection: $selectedDecadeId) {
                        ForEach(discoveryService.availableDecades) { dec in
                            Text(dec.name).tag(dec.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedDecadeId) { _, _ in updateSuggestedTitle() }
                }

                // Media Type Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Type")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    Picker("", selection: $mixerMediaType) {
                        Text("Movies").tag("movie")
                        Text("TV Series").tag("series")
                    }
                    .pickerStyle(.segmented)
                }

                // Sort By Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sort By")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    Picker("", selection: $mixerSortBy) {
                        Text("Most Popular").tag("popularity.desc")
                        Text("Highest Rated").tag("vote_average.desc")
                        Text("Newest").tag("primary_release_date.desc")
                    }
                    .pickerStyle(.menu)
                }
            }

            // Action: Generate Mix Button
            HStack(spacing: 12) {
                Button(action: {
                    runMixer()
                }) {
                    HStack(spacing: 8) {
                        if isMixing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(isMixing ? "Discovering Titles..." : "Preview Category Mix")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(SoftTone.mist.color.opacity(0.2))
                    .foregroundColor(SoftTone.mist.color)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(SoftTone.mist.color.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isMixing || (selectedGenres.isEmpty && mixerKeyword.isEmpty))

                Spacer()
            }

            // 4. Live Preview Area
            if hasGeneratedMix {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().background(Color.white.opacity(0.1))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Catalog Row Name:")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                            TextField("Enter catalog name...", text: $mixerCustomTitle)
                                .textFieldStyle(.plain)
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                                .frame(maxWidth: 380)
                        }

                        Spacer()

                        Button(action: {
                            addMixerCatalogToHome()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("+ Add Mix to Discovery Feed")
                            }
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(SoftTone.lavender.color.opacity(0.25))
                            .foregroundColor(SoftTone.lavender.color)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(SoftTone.lavender.color.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(mixedResults.isEmpty || mixerCustomTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Text("Found \(mixedResults.count) matching titles for your custom mix:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    // Horizontal Poster Previews
                    if mixedResults.isEmpty {
                        Text("No matching titles found for this combination. Try broadening your genres or keywords.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.vertical, 16)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(mixedResults) { item in
                                    VStack(alignment: .leading, spacing: 6) {
                                        CachedImage(url: item.posterUrl, fallbackURL: item.posterURL, maxPixel: 300)
                                            .frame(width: 100, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 0.8))

                                        Text(item.title)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .frame(width: 100, alignment: .leading)

                                        if let r = item.rating, r > 0 {
                                            HStack(spacing: 2) {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.yellow)
                                                Text(String(format: "%.1f", r))
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
            }
        }
    }

    private func updateSuggestedTitle() {
        var parts: [String] = []
        if !mixerKeyword.isEmpty {
            parts.append(mixerKeyword.capitalized)
        }
        let genreNames = discoveryService.availableGenres
            .filter { selectedGenres.contains($0.id) }
            .map { $0.name }
        if !genreNames.isEmpty {
            parts.append(genreNames.joined(separator: " + "))
        }
        if selectedDecadeId != "all", let dec = discoveryService.availableDecades.first(where: { $0.id == selectedDecadeId }) {
            parts.append("(\(dec.name.components(separatedBy: " ").first ?? ""))")
        }
        let generated = parts.joined(separator: " ")
        if !generated.isEmpty {
            self.mixerCustomTitle = generated
        }
    }

    private func runMixer() {
        guard !selectedGenres.isEmpty || !mixerKeyword.isEmpty else { return }
        isMixing = true
        let decade = discoveryService.availableDecades.first(where: { $0.id == selectedDecadeId })

        Task {
            let res = await discoveryService.mixCategories(
                genres: Array(selectedGenres),
                keywordQuery: mixerKeyword,
                decade: decade,
                sortBy: mixerSortBy,
                type: mixerMediaType
            )
            await MainActor.run {
                self.mixedResults = res
                self.hasGeneratedMix = true
                self.isMixing = false
                if self.mixerCustomTitle.isEmpty {
                    updateSuggestedTitle()
                }
            }
        }
    }

    private func addMixerCatalogToHome() {
        let title = mixerCustomTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom Mixed Discovery" : mixerCustomTitle
        let catID = "mixer.\(UUID().uuidString.prefix(8).lowercased())"
        let newCatalog = LiveCatalog(
            id: catID,
            name: title,
            type: mixerMediaType,
            endpointPath: nil,
            category: "Custom Discovery",
            items: mixedResults,
            lastUpdated: Date(),
            isEnabled: true
        )
        liveCatalogService.addCatalog(newCatalog)
        withAnimation {
            addedNotice = "✓ Successfully added '\(title)' to your Home discovery feed!"
        }
    }

    // MARK: - TAB 2: Ask Gemini AI
    private var geminiAITab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundColor(Color.pink.opacity(0.85))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ask Gemini AI to Bring Up Any Category")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("Describe any cinematic concept, mood, lighting, director style, or aesthetic in natural language.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()

                // API Key Settings Toggle
                Button(action: { showApiKeySettings.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                        Text(geminiApiKeyInput.isEmpty ? "Add Gemini Key" : "Gemini Key Configured")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white.opacity(0.8))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // Optional API Key Drawer
            if showApiKeySettings {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Google Gemini API Key (Optional)")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 8) {
                        SecureField("Paste your Gemini API key (AIza...)", text: $geminiApiKeyInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(6)

                        Button("Save Key") {
                            Config.geminiApiKey = geminiApiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            showApiKeySettings = false
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }

                    Text("Get a free Gemini API key at Google AI Studio (aistudio.google.com). If left blank, Somnius's smart cinema intelligence engine curates automatically!")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }

            // Quick Prompt Ideas
            VStack(alignment: .leading, spacing: 8) {
                Text("Try an evocative prompt idea:")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.6))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(promptIdeas, id: \.self) { idea in
                            Button(action: { geminiPrompt = idea }) {
                                Text(idea)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.06))
                                    .foregroundColor(.white.opacity(0.85))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Prompt Box
            VStack(alignment: .leading, spacing: 8) {
                Text("What kind of category do you want to explore?")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                TextEditor(text: $geminiPrompt)
                    .font(.subheadline)
                    .frame(height: 70)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))

                HStack {
                    Spacer()
                    Button(action: {
                        askGemini()
                    }) {
                        HStack(spacing: 8) {
                            if geminiService.isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(geminiService.isGenerating ? "Gemini is Curating..." : "Ask Gemini AI to Curate")
                        }
                        .font(.headline)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.85, green: 0.25, blue: 0.65), Color(red: 0.45, green: 0.25, blue: 0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(geminiService.isGenerating || geminiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            // Status or Error
            if let status = geminiService.statusMessage {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(.pink)
                    Text(status)
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(10)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(8)
            }

            if let err = aiErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                    Text(err).font(.caption).foregroundColor(.red)
                }
            }

            // AI Curated Category Preview
            if let catalog = aiGeneratedCatalog {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().background(Color.white.opacity(0.1))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.pink)
                                Text(catalog.name)
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                            }

                            Text(catalog.category)
                                .font(.caption.bold())
                                .foregroundColor(SoftTone.lavender.color)
                        }

                        Spacer()

                        Button(action: {
                            liveCatalogService.addCatalog(catalog)
                            withAnimation {
                                addedNotice = "✓ Successfully added '\(catalog.name)' to your Home discovery feed!"
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("+ Add AI Category to Discovery")
                            }
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.pink.opacity(0.25))
                            .foregroundColor(.pink)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pink.opacity(0.5), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Curated \(catalog.items.count) films specifically for this concept:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    // Horizontal Poster Previews
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(catalog.items) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    CachedImage(url: item.posterUrl, fallbackURL: item.posterURL, maxPixel: 300)
                                        .frame(width: 105, height: 155)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 0.8))

                                    Text(item.title)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .frame(width: 105, alignment: .leading)

                                    if let r = item.rating, r > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 8))
                                                .foregroundColor(.yellow)
                                            Text(String(format: "%.1f", r))
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.25), lineWidth: 1))
            }
        }
    }

    private func askGemini() {
        let p = geminiPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return }
        aiErrorMessage = nil

        Task {
            do {
                let cat = try await geminiService.curateCatalog(from: p, customApiKey: geminiApiKeyInput)
                await MainActor.run {
                    self.aiGeneratedCatalog = cat
                }
            } catch {
                await MainActor.run {
                    self.aiErrorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - TAB 3: Custom Manifest Endpoint
    private var customManifestTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add Custom Manifest Catalog Endpoint")
                .font(.title3.bold())
                .foregroundColor(.white)
            Text("Enter a custom Stremio, Trakt, or MDBList catalog JSON endpoint to integrate directly.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            VStack(alignment: .leading, spacing: 6) {
                Text("Catalog Name")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
                TextField("e.g. My Favorite Sci-Fi", text: $customName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Media Type")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    Picker("", selection: $customType) {
                        Text("Movie").tag("movie")
                        Text("TV Series").tag("series")
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Category Section")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    TextField("e.g. Custom Discovery", text: $customCategory)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Catalog Endpoint Path or Full URL")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
                TextField("catalog/movie/popular.json or https://...", text: $customEndpoint)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }

            Button(action: {
                guard !customName.isEmpty, !customEndpoint.isEmpty else { return }
                let newCat = LiveCatalog(
                    id: "custom.\(UUID().uuidString.prefix(8))",
                    name: customName,
                    type: customType,
                    endpointPath: customEndpoint,
                    category: customCategory.isEmpty ? "Custom Discovery" : customCategory
                )
                liveCatalogService.addCatalog(newCat)
                withAnimation {
                    addedNotice = "✓ Successfully created \(customName)!"
                    customName = ""
                    customEndpoint = ""
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Save & Add Catalog")
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(customName.isEmpty || customEndpoint.isEmpty ? Color.gray.opacity(0.3) : SoftTone.mist.color.opacity(0.18))
                .foregroundColor(customName.isEmpty || customEndpoint.isEmpty ? .white.opacity(0.5) : SoftTone.mist.color)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(customName.isEmpty || customEndpoint.isEmpty ? Color.clear : SoftTone.mist.color.opacity(0.35), lineWidth: 0.8))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(customName.isEmpty || customEndpoint.isEmpty)
        }
    }
}
