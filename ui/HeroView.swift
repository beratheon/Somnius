import SwiftUI

struct HeroView: View {
    var item: MediaItem?
    var onPlayTap: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let backdrop = item?.backdropUrl {
                AsyncImage(url: backdrop) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(height: 380)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 380)
            }

            // Gradient Overlay
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.95)]),
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("FEATURED")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(4)

                Text(item?.title ?? "Featured Content")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                if let desc = item?.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }

                HStack(spacing: 16) {
                    Button(action: { onPlayTap?() }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Play Stream")
                        }
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(20)
        }
        .frame(height: 380)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}
