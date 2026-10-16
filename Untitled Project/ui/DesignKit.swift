import SwiftUI
import AppKit
import ImageIO
import Combine

// MARK: - Soft Palette
enum SoftTone {
    case neutral, mist, sage, sand, lavender, rose

    var color: Color {
        switch self {
        case .neutral:  return Color(white: 0.82)
        case .mist:     return Color(red: 0.66, green: 0.74, blue: 0.84)   // quality
        case .sage:     return Color(red: 0.62, green: 0.76, blue: 0.66)   // instant / cached
        case .sand:     return Color(red: 0.84, green: 0.77, blue: 0.62)   // HDR / DV
        case .lavender: return Color(red: 0.74, green: 0.70, blue: 0.84)   // audio
        case .rose:     return Color(red: 0.85, green: 0.65, blue: 0.72)   // A24 / warm accent
        }
    }
}

struct SoftBadge: View {
    let text: String
    var tone: SoftTone = .neutral

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundColor(tone.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tone.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .fixedSize(horizontal: true, vertical: true)
    }
}

/// Minimal attribute row for a stream: resolution (UHD/FHD), HDR (DV/HDR10+/HDR), size, instant.
struct StreamAttributeRow: View {
    let link: AggregatedLink

    var body: some View {
        HStack(spacing: 5) {
            SoftBadge(text: link.resolutionBadge, tone: .mist)
            if let hdr = link.hdrTag { SoftBadge(text: hdr, tone: .sand) }
            if let audio = link.audioTag { SoftBadge(text: audio, tone: .lavender) }
            if let size = link.sizeString { SoftBadge(text: size, tone: .neutral) }
            if link.isCached {
                SoftBadge(text: "Instant", tone: .sage)
            } else if let s = link.seeds, s > 0 {
                if s >= 40 {
                    SoftBadge(text: "Ultra Fast", tone: .sage)
                } else if s >= 10 {
                    SoftBadge(text: "High Speed", tone: .sage)
                } else {
                    SoftBadge(text: "Standard", tone: .mist)
                }
            } else {
                SoftBadge(text: "Standard", tone: .mist)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Image Pipeline (memory cache + downsampling + request de-duplication)
/// NSCache is internally thread-safe.
final class ImageMemoryCache: @unchecked Sendable {
    static let shared = ImageMemoryCache()
    private let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 600
        c.totalCostLimit = 300 * 1024 * 1024
        return c
    }()

    func get(_ key: NSString) -> NSImage? { cache.object(forKey: key) }
    func set(_ image: NSImage, _ key: NSString) {
        cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
    }
}

actor ImagePipeline {
    static let shared = ImagePipeline()

    private var inFlight: [NSString: Task<NSImage?, Never>] = [:]

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 512 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 8
        return URLSession(configuration: config)
    }()

    nonisolated func cached(_ url: URL, maxPixel: CGFloat) -> NSImage? {
        ImageMemoryCache.shared.get(Self.key(url, maxPixel))
    }

    private static func key(_ url: URL, _ maxPixel: CGFloat) -> NSString {
        "\(url.absoluteString)#\(Int(maxPixel))" as NSString
    }

    func image(for url: URL, maxPixel: CGFloat) async -> NSImage? {
        let key = Self.key(url, maxPixel)
        if let hit = ImageMemoryCache.shared.get(key) { return hit }
        if let task = inFlight[key] { return await task.value }

        let session = self.session
        let task = Task<NSImage?, Never>.detached(priority: .userInitiated) {
            guard let (data, _) = try? await session.data(from: url) else { return nil }
            return ImagePipeline.downsample(data: data, maxPixel: maxPixel)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result { ImageMemoryCache.shared.set(result, key) }
        return result
    }

    private static func downsample(data: Data, maxPixel: CGFloat) -> NSImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts) else { return nil }
        let opts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}

/// Drop-in replacement for AsyncImage: cached, downsampled off the main thread, soft fade-in.
struct CachedImage: View {
    let url: URL?
    var fallbackURL: URL? = nil
    var maxPixel: CGFloat = 600
    var contentMode: ContentMode = .fill
    var transparentBackground: Bool = false

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if !transparentBackground {
                Color(red: 0.12, green: 0.12, blue: 0.14)
            }
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else {
            if let fallback = fallbackURL {
                await loadSingleImage(fallback)
            } else {
                image = nil
            }
            return
        }
        if let hit = ImagePipeline.shared.cached(url, maxPixel: maxPixel) {
            image = hit
            return
        }
        image = nil
        var loaded = await ImagePipeline.shared.image(for: url, maxPixel: maxPixel)
        if loaded == nil, let fallback = fallbackURL, fallback != url {
            loaded = await ImagePipeline.shared.image(for: fallback, maxPixel: maxPixel)
        }
        if !Task.isCancelled {
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }

    private func loadSingleImage(_ targetURL: URL) async {
        if let hit = ImagePipeline.shared.cached(targetURL, maxPixel: maxPixel) {
            image = hit
            return
        }
        let loaded = await ImagePipeline.shared.image(for: targetURL, maxPixel: maxPixel)
        if !Task.isCancelled {
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }
}

// MARK: - Somnius Button Micro-Interactions & Shimmers
public struct ShiningRisingModifier: ViewModifier {
    var tintColor: Color = .white
    var isWhitePlayButton: Bool = false
    @State private var isHovered: Bool = false
    
    public init(tintColor: Color = .white, isWhitePlayButton: Bool = false) {
        self.tintColor = tintColor
        self.isWhitePlayButton = isWhitePlayButton
    }
    
    public func body(content: Content) -> some View {
        content
            .offset(y: isHovered ? -2.5 : 0)
            .shadow(
                color: isWhitePlayButton
                    ? Color.white.opacity(isHovered ? 0.45 : 0.0)
                    : tintColor.opacity(isHovered ? 0.35 : 0.0),
                radius: isHovered ? 12 : 0,
                x: 0,
                y: isHovered ? 4 : 0
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isWhitePlayButton
                            ? Color.white.opacity(isHovered ? 0.9 : 0.0)
                            : tintColor.opacity(isHovered ? 0.6 : 0.0),
                        lineWidth: isHovered ? 1.2 : 0
                    )
            )
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

public struct ShiningNavModifier: ViewModifier {
    @State private var isHovered: Bool = false
    
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isHovered ? 0.55 : 0.0), lineWidth: isHovered ? 1.2 : 0)
                    .shadow(color: Color.white.opacity(isHovered ? 0.35 : 0.0), radius: isHovered ? 6 : 0)
            )
            .animation(.easeInOut(duration: 0.18), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

public extension View {
    func shiningRise(tint: Color = .white, isWhitePlay: Bool = false) -> some View {
        self.modifier(ShiningRisingModifier(tintColor: tint, isWhitePlayButton: isWhitePlay))
    }
    
    func shiningNav() -> some View {
        self.modifier(ShiningNavModifier())
    }
}

// MARK: - Proximity Heart Love Button (Pure Shine on Hover, Zero Layout Movement)
public struct ProximityLoveButton: View {
    let isFavorite: Bool
    var action: () -> Void
    @State private var isHovered: Bool = false
    
    public init(isFavorite: Bool, action: @escaping () -> Void) {
        self.isFavorite = isFavorite
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isHovered ? 0.16 : 0.08))
                
                Circle()
                    .stroke(
                        isFavorite
                            ? Color(red: 1.0, green: 0.32, blue: 0.44).opacity(0.9)
                            : (isHovered ? Color(red: 1.0, green: 0.45, blue: 0.55).opacity(0.85) : Color.white.opacity(0.18)),
                        lineWidth: isHovered ? 1.2 : 1.0
                    )
                    .shadow(
                        color: isHovered
                            ? Color(red: 1.0, green: 0.3, blue: 0.45).opacity(0.65)
                            : (isFavorite ? Color(red: 1.0, green: 0.3, blue: 0.45).opacity(0.35) : .clear),
                        radius: isHovered ? 7 : 0
                    )
                
                Image(systemName: isFavorite ? "heart.fill" : (isHovered ? "heart.fill" : "heart"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(
                        isFavorite
                            ? Color(red: 1.0, green: 0.3, blue: 0.42)
                            : (isHovered ? Color(red: 1.0, green: 0.45, blue: 0.55) : .white)
                    )
                    .shadow(
                        color: isHovered ? Color(red: 1.0, green: 0.35, blue: 0.45).opacity(0.75) : .clear,
                        radius: 5
                    )
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
            .animation(.easeInOut(duration: 0.18), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chained Poster Hover Coordinator (Clayface In-Window Overlay)
@MainActor
final class PosterHoverCoordinator: ObservableObject {
    static let shared = PosterHoverCoordinator()
    
    @Published var activeHoveredID: String? = nil
    @Published var activeHoveredItem: MediaItem? = nil
    @Published var isRoaming: Bool = false
    @Published var isHoveringCard: Bool = false
    @Published var activePosterWindowFrame: CGRect? = nil
    
    var currentlyHoveredPosterID: String? = nil
    var activeSelectAction: (() -> Void)? = nil
    
    private var hoverTimer: Timer?
    private var dismissTimer: Timer?
    private var resetTimer: Timer?
    
    private init() {}
    
    func dismiss() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
        resetTimer?.invalidate()
        resetTimer = nil
        activeHoveredID = nil
        activeHoveredItem = nil
        activeSelectAction = nil
        activePosterWindowFrame = nil
        isHoveringCard = false
        isRoaming = false
    }
    
    func triggerSelect(id: String, action: (() -> Void)?) {
        let actionToRun = action ?? (self.activeHoveredID == id ? self.activeSelectAction : nil)
        dismiss()
        actionToRun?()
    }
    
    func cursorEntered(item: MediaItem, frame: CGRect? = nil, onSelect: (() -> Void)? = nil) {
        currentlyHoveredPosterID = item.id
        if let frame = frame, frame != .zero {
            activePosterWindowFrame = frame
        }
        if let onSelect = onSelect {
            activeSelectAction = onSelect
        }
        dismissTimer?.invalidate()
        dismissTimer = nil
        resetTimer?.invalidate()
        resetTimer = nil
        hoverTimer?.invalidate()
        
        if isRoaming {
            // Already gliding across posters: show new poster preview immediately
            self.activeHoveredID = item.id
            self.activeHoveredItem = item
        } else {
            // First poster hover: short 0.22s dwell before popping up
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.currentlyHoveredPosterID == item.id {
                        self.activeHoveredID = item.id
                        self.activeHoveredItem = item
                        self.isRoaming = true
                    }
                }
            }
        }
    }
    
    func cursorExited(id: String) {
        hoverTimer?.invalidate()
        hoverTimer = nil
        
        if currentlyHoveredPosterID == id {
            currentlyHoveredPosterID = nil
        }
        
        // Fast grace window (0.06s) so cursor can move between poster and preview card.
        // If moving into empty space, vanishes rapidly.
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.isHoveringCard && self.currentlyHoveredPosterID == nil {
                    self.dismiss()
                }
            }
        }
        
        resetTimer?.invalidate()
        resetTimer = Timer.scheduledTimer(withTimeInterval: 0.14, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.isHoveringCard && self.activeHoveredID == nil {
                    self.isRoaming = false
                }
            }
        }
    }
    
    func cardHoverChanged(isHovering: Bool) {
        self.isHoveringCard = isHovering
        if isHovering {
            dismissTimer?.invalidate()
            dismissTimer = nil
            resetTimer?.invalidate()
            resetTimer = nil
        } else {
            // Fast disappearance when cursor leaves preview card to empty space (0.05s)
            dismissTimer?.invalidate()
            dismissTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if !self.isHoveringCard && self.currentlyHoveredPosterID == nil {
                        self.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Global Floating Poster Preview Overlay (In-Window Overlay - Zero NSPopover click swallowing)
struct GlobalPosterHoverOverlay: View {
    @ObservedObject private var hoverCoordinator = PosterHoverCoordinator.shared

    var body: some View {
        GeometryReader { windowGeo in
            ZStack(alignment: .topLeading) {
                if let item = hoverCoordinator.activeHoveredItem,
                   let posterFrame = hoverCoordinator.activePosterWindowFrame,
                   hoverCoordinator.activeHoveredID == item.id {
                    
                    let cardWidth: CGFloat = 290
                    let cardHeight: CGFloat = 360
                    
                    // Determine horizontal placement (prefer trailing side of poster, fallback to leading)
                    let spaceOnRight = windowGeo.size.width - posterFrame.maxX
                    let placeOnTrailing = spaceOnRight >= (cardWidth + 16)
                    
                    let targetX: CGFloat = {
                        if placeOnTrailing {
                            return posterFrame.maxX + 12
                        } else {
                            let leftPos = posterFrame.minX - cardWidth - 12
                            if leftPos >= 16 {
                                return leftPos
                            } else {
                                return max(16, min(posterFrame.maxX + 12, windowGeo.size.width - cardWidth - 16))
                            }
                        }
                    }()
                    
                    // Determine vertical placement (align top of poster, clamp between top nav and bottom window)
                    let targetY: CGFloat = {
                        let idealY = posterFrame.minY
                        let minY: CGFloat = 65
                        let maxY: CGFloat = max(minY, windowGeo.size.height - cardHeight - 20)
                        return max(minY, min(idealY, maxY))
                    }()
                    
                    ClayfacePreviewCard(item: item, onDetailsTap: {
                        hoverCoordinator.triggerSelect(id: item.id, action: hoverCoordinator.activeSelectAction)
                    })
                    .frame(width: cardWidth)
                    .offset(x: targetX, y: targetY)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: placeOnTrailing ? .leading : .trailing)),
                        removal: .opacity
                    ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Clayface Floating Poster Preview Card (Screenshot 5)
struct ClayfacePreviewCard: View {
    let item: MediaItem
    var onDetailsTap: () -> Void
    @ObservedObject private var watchlistManager = WatchlistManager.shared
    @ObservedObject private var hoverCoordinator = PosterHoverCoordinator.shared
    @State private var isBookmarked: Bool = false
    @State private var fetchedOverview: String? = nil
    @State private var fetchedYear: String? = nil
    @State private var fetchedRating: Double? = nil
    @State private var isCardHovered: Bool = false
    
    init(item: MediaItem, onDetailsTap: @escaping () -> Void) {
        self.item = item
        self.onDetailsTap = onDetailsTap
        self._isBookmarked = State(initialValue: WatchlistManager.shared.isWatchlisted(id: item.id))
    }
    
    // Check if the title is actually a new release (released within 180 days or upcoming)
    private var isActuallyNew: Bool {
        guard let date = item.releaseDate else { return false }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 999
        return days >= -30 && days <= 180
    }

    private var effectiveDescription: String {
        if let desc = item.description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
            return desc
        }
        if let ov = fetchedOverview, !ov.isEmpty {
            return ov
        }
        return "Experience this title in cinematic Ultra HD with multi-channel immersive audio."
    }

    private var effectiveYear: String {
        if let date = item.releaseDate {
            return String(Calendar.current.component(.year, from: date))
        }
        if let yr = fetchedYear, !yr.isEmpty {
            return yr
        }
        return "2026"
    }

    private var effectiveRating: Double? {
        if let r = item.rating, r > 0 {
            return r
        }
        if let r = fetchedRating, r > 0 {
            return r
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Backdrop Image with Intelligent Badge
            ZStack(alignment: .topLeading) {
                CachedImage(url: item.backdropUrl ?? item.posterUrl, maxPixel: 800)
                    .frame(width: 290, height: 165)
                    .clipped()
                
                LinearGradient(
                    colors: [Color.clear, Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                // Show NEW only if actually new; show TOP RATED for classics/high-rated
                if isActuallyNew {
                    Text("NEW")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.8))
                        .padding(10)
                } else if let r = effectiveRating, r >= 8.5 {
                    Text("TOP RATED")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundColor(SoftTone.sand.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(SoftTone.sand.color.opacity(0.4), lineWidth: 0.8))
                        .padding(10)
                }
            }
            .frame(width: 290, height: 165)
            .contentShape(Rectangle())
            .onTapGesture {
                onDetailsTap()
            }
            
            // Bottom Metadata and Actions
            VStack(alignment: .leading, spacing: 7) {
                Text(item.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .onTapGesture {
                        onDetailsTap()
                    }
                
                // Year & Genre
                HStack(spacing: 6) {
                    Text(effectiveYear)
                    Text("•")
                    Text(item.type == .series ? "Series" : "Film")
                    if let r = effectiveRating, r > 0 {
                        Text("•")
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 8))
                            Text(String(format: "%.1f", r))
                        }
                        .foregroundColor(SoftTone.sand.color)
                    }
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                
                // Truncated Synopsis
                Text(effectiveDescription)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(3)
                    .lineSpacing(2.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                
                // Action Bar: Details Button & Bookmark
                HStack {
                    Button(action: {
                        onDetailsTap()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("DETAILS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.8))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            watchlistManager.toggleWatchlist(item)
                            isBookmarked.toggle()
                        }
                    }) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isBookmarked ? SoftTone.sand.color : .white.opacity(0.75))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(isBookmarked ? "Remove from Watchlist" : "Add to Watchlist")
                }
                .padding(.top, 6)
            }
            .padding(14)
            .background(Color(red: 0.11, green: 0.11, blue: 0.13))
        }
        .frame(width: 290)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(isCardHovered ? 0.75 : 0.16), lineWidth: isCardHovered ? 1.6 : 1.0)
        )
        .shadow(
            color: isCardHovered ? Color.white.opacity(0.22) : Color.black.opacity(0.85),
            radius: isCardHovered ? 26 : 24,
            x: 0,
            y: isCardHovered ? 8 : 12
        )
        .zIndex(100)
        .contentShape(Rectangle())
        .onTapGesture {
            onDetailsTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isCardHovered = hovering
            }
            hoverCoordinator.cardHoverChanged(isHovering: hovering)
        }
        .task(id: item.id) {
            let needsOverview = (item.description == nil || item.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true)
            let needsRating = (item.rating == nil || item.rating == 0)
            let needsYear = (item.releaseDate == nil)
            if needsOverview || needsRating || needsYear {
                let details = await TMDBService().fetchMediaLogoAndDetails(id: item.id, imdbID: item.imdbID, type: item.type, title: item.title, year: item.releaseYear)
                if let ov = details.overview, !ov.isEmpty {
                    self.fetchedOverview = ov
                }
                if let yr = details.year, !yr.isEmpty {
                    self.fetchedYear = yr
                }
                if let rt = details.rating, rt > 0 {
                    self.fetchedRating = rt
                }
            }
        }
    }
}


