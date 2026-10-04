import SwiftUI
import Combine

struct HeroView: View {
    let items: [MediaItem]
    var onPlayTap: ((MediaItem) -> Void)?

    @State private var currentIndex: Int = 0
    @State private var timer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()

    var currentItem: MediaItem? {
        guard !items.isEmpty else { return nil }
        return items[currentIndex % items.count]
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop Image with smooth opacity transition
            if let item = currentItem {
                ZStack {
                    if let backdrop = item.backdropUrl ?? item.posterUrl {
                        AsyncImage(url: backdrop) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                        .id(item.id)
                        .transition(.opacity.animation(.easeInOut(duration: 0.8)))
                        .frame(height: 400)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(height: 400)
                    }
                }
            }

            // Dark Vignette & Gradient Overlays
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.5), .black.opacity(0.95)]),
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                gradient: Gradient(colors: [.black.opacity(0.7), .clear]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 550)

            VStack(alignment: .leading, spacing: 14) {
                if let item = currentItem {
                    HStack(spacing: 8) {
                        Text(item.type == .series ? "FEATURED SERIES" : "FEATURED MOVIE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.25))
                            .foregroundColor(.white)
                            .clipShape(Capsule())

                        Text("4K HDR • DOLBY VISION")
                            .font(.caption2.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.yellow.opacity(0.3))
                            .foregroundColor(.yellow)
                            .clipShape(Capsule())

                        if let rating = item.rating, rating > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption2.bold())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.3))
                            .foregroundColor(.cyan)
                            .clipShape(Capsule())
                        }
                    }

                    Text(item.title)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.8), radius: 8)

                    if let desc = item.description, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                            .frame(maxWidth: 650, alignment: .leading)
                            .shadow(color: .black.opacity(0.8), radius: 6)
                    }

                    HStack(spacing: 20) {
                        Button(action: {
                            if let item = currentItem {
                                onPlayTap?(item)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.headline)
                                Text("Play 4K • \(item.title)")
                                    .font(.headline.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.white)
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Carousel Indicators / Paging Dots
                        if items.count > 1 {
                            HStack(spacing: 8) {
                                ForEach(0..<items.count, id: \.self) { idx in
                                    Circle()
                                        .fill(idx == currentIndex ? Color.white : Color.white.opacity(0.3))
                                        .frame(width: idx == currentIndex ? 10 : 7, height: idx == currentIndex ? 10 : 7)
                                        .scaleEffect(idx == currentIndex ? 1.2 : 1.0)
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.4)) {
                                                currentIndex = idx
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(28)

            // Chevron Navigation Arrows
            if items.count > 1 {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentIndex = (currentIndex - 1 + items.count) % items.count
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentIndex = (currentIndex + 1) % items.count
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 160)
            }
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal)
        .onReceive(timer) { _ in
            if items.count > 1 {
                withAnimation(.easeInOut(duration: 0.6)) {
                    currentIndex = (currentIndex + 1) % items.count
                }
            }
        }
    }
}
