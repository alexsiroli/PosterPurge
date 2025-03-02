import SwiftUI
import UIKit

struct ActivityViewControllerWrapper: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PosterDetailView: View, Identifiable {
    var id: UUID { posterItem.id }
    let posterItem: PosterItem
    @EnvironmentObject var libraryVM: LibraryViewModel

    @State private var generatedPoster: UIImage?
    @State private var showGeneratedFullScreen = false
    @State private var showingChangeSheet = false
    @State private var searchResults: [TMDbService.TMDbSearchResult] = []
    @State private var newImages: [UIImage] = []
    @State private var isTV = false
    @State private var query = "" // per la manual search
    @State private var yearGuess: Int? = nil
    @State private var isProcessing = false

    var body: some View {
        NavigationView {
            VStack {
                posterItem.image
                    .resizable()
                    .scaledToFit()
                    .padding()

                Text(posterItem.movie.title)
                    .font(.title)
                    .fontWeight(.bold)
                Text("Anno: \(posterItem.movie.year)")
                Text("Voto: \(posterItem.movie.rating)/10")
                Text("Data visione: \(posterItem.movie.dateWatched)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider().padding()

                Spacer()

                HStack {
                    Button("Poster Tradizionale") {
                        generatePoster(layout: "traditional")
                    }
                    .padding()

                    Button("Poster Moderno") {
                        generatePoster(layout: "modern")
                    }
                    .padding()
                }

                Button("Scarica Poster Grezzo") {
                    if let base = posterItem.uiImage {
                        UIImageWriteToSavedPhotosAlbum(base, nil, nil, nil)
                    }
                }

                Button("Cambia Locandina") {
                    isTV = posterItem.movie.isTV
                    query = posterItem.movie.title
                    if let y = Int(posterItem.movie.year) { yearGuess = y }
                    else { yearGuess = nil }
                    showingChangeSheet = true
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Dettagli Poster")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showGeneratedFullScreen) {
                if let g = generatedPoster {
                    FullScreenPosterView(uiImage: g, onClose: { showGeneratedFullScreen = false })
                }
            }
            .sheet(isPresented: $showingChangeSheet) {
                changePosterSheet()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func generatePoster(layout: String) {
        guard let base = posterItem.uiImage else { return }
        let newImg = PosterGenerator.shared.generatePoster(baseImage: base, layout: layout, movie: posterItem.movie)
        self.generatedPoster = newImg
        showGeneratedFullScreen = true
    }
    
    // MARK: - Sheet per cambiare locandina
    @ViewBuilder
    private func changePosterSheet() -> some View {
        NavigationView {
            VStack {
                if isProcessing {
                    ProgressView("Caricamento...").padding()
                } else if !newImages.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(0..<newImages.count, id: \.self) { i in
                                Button {
                                    applyNewPoster(newImages[i])
                                } label: {
                                    Image(uiImage: newImages[i])
                                        .resizable()
                                        .scaledToFit()
                                }
                            }
                        }
                        .padding()
                    }
                } else if !searchResults.isEmpty {
                    Text("Seleziona poster in base ai result")
                    List(searchResults, id: \.id) { r in
                        Button {
                            loadPostersFrom(r)
                        } label: {
                            let nm = isTV ? (r.name ?? "") : (r.title ?? "")
                            let y = isTV ? r.first_air_date : r.release_date
                            Text("\(nm) (\(y?.prefix(4) ?? "????"))")
                        }
                    }
                } else {
                    Form {
                        TextField("Titolo", text: $query)
                        Toggle("È Serie TV?", isOn: $isTV)
                        TextField("Anno (opzionale)", value: $yearGuess, format: .number)
                            .keyboardType(.numberPad)
                        Button("Cerca su TMDb") {
                            Task { await doSearchChange() }
                        }
                    }
                }
            }
            .navigationBarItems(trailing: Button("Chiudi") { showingChangeSheet = false })
            .navigationTitle("Cambia Locandina")
        }
    }
    
    private func applyNewPoster(_ newPoster: UIImage) {
        showingChangeSheet = false
        isProcessing = true
        Task {
            do {
                let yInt = yearGuess
                let results = try await TMDbService.shared.search(
                    query: query,
                    mediaType: isTV ? .tv : .movie,
                    year: yInt
                )
                if let first = results.first {
                    let details = try await fetchTMDbDetails(itemID: first.id, isTV: isTV)
                    let old = posterItem.movie
                    let newMov = MovieModel(
                        title: details.title,
                        year: details.year,
                        rating: old.rating,
                        dateWatched: old.dateWatched,
                        isTV: old.isTV
                    )
                    libraryVM.removePoster(posterItem)
                    let updated = PosterItem(
                        id: UUID(),
                        movie: newMov,
                        uiImage: newPoster,
                        timestamp: Date(),
                        imageFilename: nil
                    )
                    libraryVM.addPoster(updated)
                }
            } catch {
                libraryVM.removePoster(posterItem)
                let updated = PosterItem(
                    id: UUID(),
                    movie: posterItem.movie,
                    uiImage: newPoster,
                    timestamp: Date(),
                    imageFilename: nil
                )
                libraryVM.addPoster(updated)
            }
            isProcessing = false
        }
    }
    
    private func loadPostersFrom(_ r: TMDbService.TMDbSearchResult) {
        isProcessing = true
        newImages = []
        Task {
            do {
                let info = try await TMDbService.shared.fetchImages(for: r.id, mediaType: isTV ? .tv : .movie)
                let subset = info.posters.prefix(16)
                var tmp: [UIImage] = []
                for p in subset {
                    if let d = try await TMDbService.shared.downloadImage(path: p.file_path) {
                        tmp.append(d)
                    }
                }
                await MainActor.run {
                    newImages = tmp
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
    
    private func doSearchChange() async {
        searchResults = []
        newImages = []
        isProcessing = true
        defer { isProcessing = false }
        do {
            let results = try await TMDbService.shared.search(
                query: query,
                mediaType: isTV ? .tv : .movie,
                year: yearGuess
            )
            searchResults = results
        } catch {
            print("Errore doSearchChange:", error.localizedDescription)
        }
    }
    
    private func fetchTMDbDetails(itemID: Int, isTV: Bool) async throws -> (title: String, year: String) {
        if isTV {
            let urlString = "https://api.themoviedb.org/3/tv/\(itemID)?api_key=\(TMDbService.shared.apiKey)&language=it-IT"
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }
            let (data, _) = try await URLSession.shared.data(from: url)
            let info = try JSONDecoder().decode(TVDetails.self, from: data)
            let nm = info.name.isEmpty ? (info.original_name ?? "??") : info.name
            let fd = info.first_air_date ?? ""
            let y = fd.count >= 4 ? String(fd.prefix(4)) : "????"
            return (nm, y)
        } else {
            let urlString = "https://api.themoviedb.org/3/movie/\(itemID)?api_key=\(TMDbService.shared.apiKey)&language=it-IT"
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }
            let (data, _) = try await URLSession.shared.data(from: url)
            let info = try JSONDecoder().decode(MovieDetails.self, from: data)
            let ti = info.title.isEmpty ? (info.original_title ?? "??") : info.title
            let rd = info.release_date ?? ""
            let y = rd.count >= 4 ? String(rd.prefix(4)) : "????"
            return (ti, y)
        }
    }
}

struct TVDetails: Codable {
    let name: String
    let original_name: String?
    let first_air_date: String?
}

struct MovieDetails: Codable {
    let title: String
    let original_title: String?
    let release_date: String?
}

// MARK: - FullScreenPosterView
struct FullScreenPosterView: View {
    let uiImage: UIImage
    let onClose: () -> Void
    
    @State private var showingShare = false
    
    var body: some View {
        NavigationView {
            VStack {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
                HStack {
                    Button("Salva su Rullino") {
                        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                    }
                    .padding()
                    
                    Button("Condividi") {
                        showingShare = true
                    }
                    .padding()
                    .sheet(isPresented: $showingShare) {
                        ActivityViewControllerWrapper(activityItems: [uiImage])
                    }
                }
            }
            .navigationBarItems(trailing: Button("Chiudi") { onClose() })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
