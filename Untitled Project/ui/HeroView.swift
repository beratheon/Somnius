import SwiftUI
import Combine

struct HeroView: View {
    let items: [MediaItem]
    var onPlayTap: ((MediaItem) -> Void)?

    @State private var currentIndex: Int = 0
    @State private var isHovering: Bool = false
    @State private var timer = Timer.publish(every: 7, on: .main, in: .common).autoconnect()
    @StateObject private var watchlistManager = WatchlistManager.shared
    @State private var logoURL: URL? = nil
    @State private var isLoadingLogo: Bool = false

    private let tmdbService = TMDBService()

    var currentItem: MediaItem? {
        guard !items.isEmpty else { return nil }
        return items[currentIndex % items.count]
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 1. Ambient Glow & Backdrop Layer with Poster Hover Filter
            if let item = currentItem {
                ZStack {
                    CachedImage(url: item.backdropUrl ?? item.posterUrl, maxPixel: 2400)
                        .id(item.id)
                        .transition(.opacity.animation(.easeInOut(duration: 0.6)))
                        .grayscale(isHovering ? 0.0 : 0.45)
                        .contrast(isHovering ? 1.0 : 1.08)
                        .saturation(isHovering ? 1.0 : 0.88)
                        .brightness(isHovering ? 0.0 : -0.02)
                        .scaleEffect(isHovering ? 1.025 : 1.0)
                        .animation(.easeInOut(duration: 0.35), value: isHovering)
                }
                .frame(maxWidth: .infinity, maxHeight: 520)
                .clipped()
            }

            // 2. Cinematic Progressive Gradients (Apple TV+ Style)
            // Bottom fade
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.06, green: 0.06, blue: 0.07).opacity(0.4),
                    Color(red: 0.06, green: 0.06, blue: 0.07).opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Leading vignette for text & logo legibility
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.06).opacity(0.92),
                    Color(red: 0.05, green: 0.05, blue: 0.06).opacity(0.65),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 720)

            // 3. Apple TV+ Metadata & Action Controls
            VStack(alignment: .leading, spacing: 14) {
                if let item = currentItem {
                    // Eyebrow: type, year, rating
                    HStack(spacing: 8) {
                        Text(item.type == .series ? "SERIES" : "FILM")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.4)
                            .foregroundColor(.white.opacity(0.6))
                        if let date = item.releaseDate {
                            Text("·").foregroundColor(.white.opacity(0.3))
                            Text(String(Calendar.current.component(.year, from: date)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        if let rating = item.rating, rating > 0 {
                            Text("·").foregroundColor(.white.opacity(0.3))
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill").font(.system(size: 8))
                                Text(String(format: "%.1f", rating)).font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(SoftTone.sand.color)
                        }
                    }

                    // Logo Art Header or Sleek Typographic Fallback
                    Group {
                        if let logo = logoURL {
                            CachedImage(url: logo, maxPixel: 1200, contentMode: .fit, transparentBackground: true)
                                .frame(maxWidth: 420, maxHeight: 95, alignment: .leading)
                                .shadow(color: .black.opacity(0.85), radius: 10, x: 0, y: 4)
                        } else if !isLoadingLogo {
                            Text(item.title)
                                .font(.system(size: 42, weight: .heavy, design: .default))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .shadow(color: .black.opacity(0.8), radius: 6, x: 0, y: 3)
                        } else {
                            // Subtle placeholder preserving vertical metrics while fetching logo
                            Text(item.title)
                                .font(.system(size: 42, weight: .heavy, design: .default))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .shadow(color: .black.opacity(0.8), radius: 6, x: 0, y: 3)
                        }
                    }
                    .frame(height: 95, alignment: .bottomLeading)

                    // Synopsis / Description
                    if let desc = item.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(3)
                            .lineSpacing(3.5)
                            .frame(maxWidth: 640, alignment: .leading)
                            .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
                    }

                    // Action Buttons Row
                    HStack(spacing: 14) {
                        // Play / Continue Button
                        let inWatchlist = currentItem != nil ? watchlistManager.isWatchlisted(id: currentItem!.id) : false
                        let historyItem = currentItem != nil ? watchlistManager.history.first(where: { $0.mediaItem.id == currentItem!.id }) : nil
                        let hasWatchedProgress = (historyItem != nil && historyItem!.progressSeconds > 10)
                        let shouldShowContinue = inWatchlist && hasWatchedProgress

                        Button(action: {
                            if let item = currentItem {
                                onPlayTap?(item)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: shouldShowContinue ? "arrow.clockwise.circle.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text(shouldShowContinue ? "Continue" : "Play")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Watchlist Button (Frosted Glass)
                        let isSaved = watchlistManager.isWatchlisted(id: item.id)
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                watchlistManager.toggleWatchlist(item)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isSaved ? "checkmark" : "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text(isSaved ? "In Watchlist" : "Watchlist")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())


                        Spacer()

                        // Apple TV+ Style Slide Capsule Indicators
                        if items.count > 1 {
                            HStack(spacing: 6) {
                                ForEach(0..<items.count, id: \.self) { idx in
                                    Capsule()
                                        .fill(idx == currentIndex ? Color.white : Color.white.opacity(0.25))
                                        .frame(width: idx == currentIndex ? 24 : 7, height: 6)
                                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.4)) {
                                                currentIndex = idx
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 32)

            // Side Navigation Chevrons (Appear on Hover)
            if items.count > 1 && isHovering {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentIndex = (currentIndex - 1 + items.count) % items.count
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentIndex = (currentIndex + 1) % items.count
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 200)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .frame(height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
        .onHover { hovering in
            isHovering = hovering
        }
        .onReceive(timer) { _ in
            if items.count > 1 && !isHovering {
                withAnimation(.easeInOut(duration: 0.6)) {
                    currentIndex = (currentIndex + 1) % items.count
                }
            }
        }
        .onAppear {
            loadLogo(for: currentItem)
        }
        .onChange(of: currentIndex) { _ in
            loadLogo(for: currentItem)
        }
    }

    private func loadLogo(for item: MediaItem?) {
        guard let item = item else {
            self.logoURL = nil
            self.isLoadingLogo = false
            return
        }

        if let initial = item.initialLogoURL {
            self.logoURL = initial
            self.isLoadingLogo = false
            return
        }

        self.isLoadingLogo = true
        self.logoURL = nil

        Task {
            let details = await tmdbService.fetchMediaLogoAndDetails(
                id: item.id,
                imdbID: item.imdbID,
                type: item.type,
                title: item.title
            )
            await MainActor.run {
                if currentItem?.id == item.id {
                    self.logoURL = details.logoURL
                    self.isLoadingLogo = false
                }
            }
        }
    }
}
