import SwiftUI
import AppKit
import ImageIO

// MARK: - Soft Palette
enum SoftTone {
    case neutral, mist, sage, sand, lavender

    var color: Color {
        switch self {
        case .neutral:  return Color(white: 0.82)
        case .mist:     return Color(red: 0.66, green: 0.74, blue: 0.84)   // quality
        case .sage:     return Color(red: 0.62, green: 0.76, blue: 0.66)   // instant / cached
        case .sand:     return Color(red: 0.84, green: 0.77, blue: 0.62)   // HDR / DV
        case .lavender: return Color(red: 0.74, green: 0.70, blue: 0.84)   // audio
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
    }
}

/// Minimal attribute row for a stream: resolution (UHD/FHD), HDR (DV/HDR10+/HDR), size, instant.
struct StreamAttributeRow: View {
    let link: AggregatedLink

    var body: some View {
        HStack(spacing: 5) {
            SoftBadge(text: link.resolutionBadge, tone: .mist)
            if let hdr = link.hdrTag { SoftBadge(text: hdr, tone: .sand) }
            if let size = link.sizeString { SoftBadge(text: size, tone: .neutral) }
            if link.isCached { SoftBadge(text: "Instant", tone: .sage) }
        }
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
            guard let url else { image = nil; return }
            if let hit = ImagePipeline.shared.cached(url, maxPixel: maxPixel) {
                image = hit
                return
            }
            image = nil
            let loaded = await ImagePipeline.shared.image(for: url, maxPixel: maxPixel)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.2)) { image = loaded }
            }
        }
    }
}
