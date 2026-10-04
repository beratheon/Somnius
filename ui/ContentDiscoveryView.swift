import SwiftUI

struct ContentDiscoveryView: View {
    @ObservedObject var viewModel: ContentViewModel
    var onMediaSelected: (MediaItem) -> Void
    var onOpenProfile: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.6))
                    TextField("Search movies or series...", text: $viewModel.searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .onSubmit {
                            viewModel.performSearch()
                        }
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.clearSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(15)
                .padding(.horizontal)

                if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Search Mode
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Search Results for \"\(viewModel.searchQuery)\"")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Spacer()
                            if viewModel.isSearching {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .padding(.horizontal)

                        if viewModel.isSearching && viewModel.searchResults.isEmpty {
                            HStack {
                                Spacer()
                                Text("Searching TMDB...")
                                    .foregroundColor(.gray)
                                    .padding(.top, 40)
                                Spacer()
                            }
                        } else if viewModel.searchResults.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "film.stack")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("No results found for \"\(viewModel.searchQuery)\"")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Check the spelling or try searching for another title.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(viewModel.searchResults) { item in
                                    MoviePosterCard(item: item)
                                        .onTapGesture {
                                            onMediaSelected(item)
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else if viewModel.isLoading {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("Connecting to RealDebrid & TMDB...")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.subheadline)
                        }
                        .padding(.top, 40)
                        Spacer()
                    }
                } else if viewModel.trendingMovies.isEmpty && viewModel.popularMovies.isEmpty {
                    // Empty State / Network Error Retry Mode
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)

                        Text("Unable to load catalog metadata")
                            .font(.title3.bold())
                            .foregroundColor(.white)

                        if let err = viewModel.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Button(action: {
                            viewModel.fetchContent()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Reload Library Catalog")
                            }
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    // Discovery Main Mode
                    if let featured = viewModel.trendingMovies.first {
                        HeroView(item: featured) {
                            onMediaSelected(featured)
                        }
                    }

                    if let user = viewModel.rdUser {
                        RealDebridUserBanner(user: user, onProfileTap: onOpenProfile)
                            .padding(.horizontal)
                    }

                    if !viewModel.trendingMovies.isEmpty {
                        ContentSection(title: "Trending Movies", items: viewModel.trendingMovies, onSelect: onMediaSelected)
                    }

                    if !viewModel.popularMovies.isEmpty {
                        ContentSection(title: "Popular Content", items: viewModel.popularMovies, onSelect: onMediaSelected)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

struct RealDebridUserBanner: View {
    let user: RealDebridUser
    var onProfileTap: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("RealDebrid Account: \(user.username)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Text("Status: \(user.type.capitalized) • Points: \(user.points ?? 0)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button(action: onProfileTap) {
                Text("Debrid Cloud")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct ContentSection: View {
    let title: String
    let items: [MediaItem]
    var onSelect: (MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        MoviePosterCard(item: item)
                            .onTapGesture {
                                onSelect(item)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct MoviePosterCard: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let posterUrl = item.posterUrl {
                    AsyncImage(url: posterUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView().tint(.white))
                    }
                    .frame(width: 140, height: 210)
                    .cornerRadius(12)
                    .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 140, height: 210)
                        .overlay(
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.5))
                        )
                }

                if let rating = item.rating, rating > 0 {
                    Text(String(format: "%.1f", rating))
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.yellow)
                        .cornerRadius(6)
                        .padding(6)
                }
            }

            Text(item.title)
                .font(.caption.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
        }
    }
}
