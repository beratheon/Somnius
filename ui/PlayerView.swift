import SwiftUI
import AVKit

#if os(macOS)
import AppKit

struct NativePlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .inline
        playerView.showsFullScreenToggleButton = true
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
#endif

struct PlayerView: View {
    var streamURL: URL?
    var mediaItem: MediaItem?

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var subtitles: [SubtitleTrack] = []
    @State private var selectedSubtitle: SubtitleTrack?
    @State private var isLoadingSubtitles: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                #if os(macOS)
                NativePlayerView(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
                #else
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
                #endif
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.3)
                    Text("Preparing Direct RealDebrid Stream...")
                        .foregroundColor(.white)
                        .font(.headline)
                    if let url = streamURL {
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .padding(.horizontal)
                    }
                }
            }

            // Overlay Navigation Controls
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mediaItem?.title ?? "Debrid Stream")
                            .font(.title3.bold())
                            .foregroundColor(.white)

                        Text("Preferred Subtitle: \(SubtitleService.languageName(for: Config.preferredSubtitleLanguage))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding()

                    Spacer()

                    // Subtitle Picker Menu
                    Menu {
                        Button("Subtitles Off") {
                            selectedSubtitle = nil
                        }

                        Divider()

                        ForEach(subtitles) { sub in
                            Button(sub.label) {
                                selectedSubtitle = sub
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "captions.bubble.fill")
                            Text(selectedSubtitle?.label ?? (isLoadingSubtitles ? "Loading Subs..." : "Subtitles"))
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.trailing, 8)

                    // Close Button
                    Button(action: {
                        player?.pause()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.85))
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let url = streamURL {
                let avPlayer = AVPlayer(url: url)
                self.player = avPlayer

                // Fetch Subtitles
                if let item = mediaItem {
                    Task {
                        isLoadingSubtitles = true
                        let imdb = item.imdbID ?? item.id
                        let tracks = await SubtitleService().fetchSubtitles(imdbID: imdb, type: item.type)
                        await MainActor.run {
                            self.subtitles = tracks
                            self.selectedSubtitle = tracks.first(where: { $0.lang == Config.preferredSubtitleLanguage }) ?? tracks.first
                            self.isLoadingSubtitles = false
                        }
                    }
                }
            }
        }
    }
}
