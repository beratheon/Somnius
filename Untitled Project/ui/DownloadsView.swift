import SwiftUI

struct DownloadsView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    var onMediaSelected: (MediaItem) -> Void
    @State private var hoveredItemID: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Top Header Bar
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.35, blue: 0.35))
                                .frame(width: 8, height: 8)
                            Text("DOWNLOADS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                                .tracking(1.5)
                        }
                        Text("Download Manager")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Destination Folder Selector
                    Button(action: {
                        downloadManager.promptForDownloadDirectory { _ in }
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                            Text(downloadManager.downloadDirectory?.lastPathComponent ?? "Downloads")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Change download directory folder")
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                
                // Active In-Progress Downloads Bar
                let inProgress = downloadManager.isDownloading.filter { $0.value }
                if !inProgress.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("ACTIVE TRANSFERS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                                .tracking(1.2)
                            Spacer()
                            Text("\(inProgress.count) downloading")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        ForEach(Array(inProgress.keys), id: \.self) { itemId in
                            let progress = downloadManager.downloadProgress[itemId] ?? 0.0
                            let speed = downloadManager.downloadSpeed[itemId] ?? "Connecting..."
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 1.0, green: 0.35, blue: 0.35)))
                                        .scaleEffect(0.8)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Downloading Stream...")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(speed)
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(Int(progress * 100))%")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                                }
                                
                                // Glowing Progress Bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(red: 1.0, green: 0.45, blue: 0.45), Color(red: 0.88, green: 0.2, blue: 0.2)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geo.size.width * CGFloat(min(1.0, max(0.02, progress))), height: 6)
                                            .shadow(color: Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.5), radius: 4, x: 0, y: 1)
                                    }
                                }
                                .frame(height: 6)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.2), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 28)
                }
                
                // Downloaded Library Grid
                if downloadManager.downloadedItems.isEmpty && inProgress.isEmpty {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.12))
                                .frame(width: 80, height: 80)
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 38))
                                .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
                        }
                        Text("No Downloads Yet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Click Download on any movie or series to pick a source link and store it locally.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 380)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else if !downloadManager.downloadedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("COMPLETED DOWNLOADS (\(downloadManager.downloadedItems.count))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1.2)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 200), spacing: 20)], spacing: 24) {
                            ForEach(downloadManager.downloadedItems) { item in
                                let isHovered = hoveredItemID == item.id
                                ZStack(alignment: .topTrailing) {
                                    Button(action: {
                                        onMediaSelected(item)
                                    }) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ZStack(alignment: .bottomLeading) {
                                                CachedImage(url: item.posterURL, maxPixel: 400)
                                                    .aspectRatio(2/3, contentMode: .fill)
                                                    .frame(maxWidth: .infinity)
                                                    .cornerRadius(12)
                                                    .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 5)
                                                
                                                // Downloaded Badge
                                                HStack(spacing: 4) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(Color(red: 0.3, green: 0.9, blue: 0.5))
                                                    Text("Ready Offline")
                                                        .font(.system(size: 9, weight: .bold))
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.black.opacity(0.8))
                                                .clipShape(Capsule())
                                                .padding(8)
                                            }
                                            
                                            Text(item.title)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // Delete Download Button
                                    Button(action: {
                                        downloadManager.deleteDownload(item: item)
                                    }) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 28, height: 28)
                                            .background(Color.red.opacity(0.85))
                                            .clipShape(Circle())
                                            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(8)
                                    .opacity(isHovered ? 1.0 : 0.8)
                                    .help("Delete local file")
                                }
                                .onHover { h in hoveredItemID = h ? item.id : nil }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                }
            }
            .padding(.bottom, 48)
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.07))
    }
}
