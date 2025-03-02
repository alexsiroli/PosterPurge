import SwiftUI

struct SearchView: View {
    @ObservedObject var libraryVM: LibraryViewModel
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Environment(\.presentationMode) var presentationMode

    @State private var query = ""
    @State private var isTV = false
    @State private var results: [TMDbService.TMDbSearchResult] = []

    @State private var selectedYear = ""
    @State private var userRating = 5
    @State private var dateWatched = ""

    @State private var posterImages: [UIImage] = []
    @State private var chosenPoster: UIImage?
    @State private var selectedItem: TMDbService.TMDbSearchResult?

    @State private var phase = 0

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            Group {
                switch phase {
                case 0: phase0View()
                case 1: phase1View()
                case 2: phase2View()
                default: phase3View()
                }
            }
            .navigationTitle("Cerca Film/Serie")
            .navigationBarItems(leading: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear { resetState() }
        }
    }
    
    @ViewBuilder
    private func phase0View() -> some View {
        Form {
            Section(header: Text("Dati Film/Serie")) {
                TextField("Nome Film/Serie", text: $query)
                Toggle("È una Serie TV?", isOn: $isTV)
                TextField("Anno (opzionale)", text: $selectedYear)
                    .keyboardType(.numberPad)
            }
            Section(header: Text("Tuoi dati/Rating")) {
                Stepper("Voto (1-10): \(userRating)", value: $userRating, in: 1...10)
                TextField("Data visione (AAAA-MM-GG)", text: $dateWatched)
            }
            Section {
                Button("Cerca") { search() }
            }
        }
    }
    
    @ViewBuilder
    private func phase1View() -> some View {
        VStack {
            if results.isEmpty {
                Text("Nessun risultato trovato.").padding()
            } else {
                List(results, id: \.id) { item in
                    Button {
                        handleResultSelection(item)
                    } label: {
                        Text("\(item.displayTitle) (\(item.releaseYear))")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func phase2View() -> some View {
        VStack {
            Text("Scegli Poster")
                .font(.headline)
                .padding()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(0..<posterImages.count, id: \.self) { i in
                        Button {
                            chosenPoster = posterImages[i]
                            generateFinalPoster()
                        } label: {
                            Image(uiImage: posterImages[i])
                                .resizable()
                                .scaledToFit()
                                .frame(minWidth: 0, maxWidth: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private func phase3View() -> some View {
        VStack(spacing: 20) {
            Text("Poster generato e aggiunto in libreria!")
                .font(.title2)
                .padding()
            Button("Fine") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
    }
    
    private func search() {
        phase = 1
        results = []
        posterImages = []
        chosenPoster = nil
        Task {
            do {
                let yInt = Int(selectedYear)
                let found = try await TMDbService.shared.search(
                    query: query,
                    mediaType: isTV ? .tv : .movie,
                    year: yInt
                )
                results = found
            } catch {
                print("Errore ricerca:", error.localizedDescription)
            }
        }
    }
    
    private func handleResultSelection(_ item: TMDbService.TMDbSearchResult) {
        selectedItem = item
        let y = isTV ? item.first_air_date : item.release_date
        if let ys = y, ys.count >= 4, selectedYear.isEmpty {
            selectedYear = String(ys.prefix(4))
        }
        fetchPosters(for: item)
    }
    
    // Aggiornamento qui: mostra subito la schermata dei poster (fase 2) e aggiunge progressivamente le immagini,
    // controllando che il film selezionato non sia cambiato.
    private func fetchPosters(for item: TMDbService.TMDbSearchResult) {
        Task {
            do {
                let currentItemID = item.id
                let imagesResp = try await TMDbService.shared.fetchImages(
                    for: item.id,
                    mediaType: isTV ? .tv : .movie
                )
                let subset = imagesResp.posters.prefix(50)
                await MainActor.run {
                    // Presenta subito la schermata dei poster solo se il film selezionato è ancora quello attuale
                    if selectedItem?.id == currentItemID {
                        posterImages = []
                        phase = 2
                    }
                }
                for p in subset {
                    if let d = try await TMDbService.shared.downloadImage(path: p.file_path) {
                        await MainActor.run {
                            // Aggiorna le immagini solo se il film selezionato non è cambiato
                            if selectedItem?.id == currentItemID {
                                posterImages.append(d)
                            }
                        }
                    }
                }
            } catch {
                print("Errore fetch poster:", error.localizedDescription)
                await MainActor.run { phase = 0 }
            }
        }
    }
    
    private func generateFinalPoster() {
        guard let base = chosenPoster, let sel = selectedItem else { return }
        Task {
            do {
                let det = try await fetchTMDbDetails(itemID: sel.id, isTV: isTV)
                let finalMovie = MovieModel(
                    title: det.title,
                    year: det.year,
                    rating: userRating,
                    dateWatched: dateWatched,
                    isTV: isTV
                )
                let item = PosterItem(
                    id: UUID(),
                    movie: finalMovie,
                    uiImage: base,
                    timestamp: Date(),
                    imageFilename: nil
                )
                libraryVM.addPoster(item)
                phase = 3
            } catch {
                print("Errore details:", error.localizedDescription)
                let fallback = MovieModel(
                    title: query,
                    year: selectedYear,
                    rating: userRating,
                    dateWatched: dateWatched,
                    isTV: isTV
                )
                let item = PosterItem(
                    id: UUID(),
                    movie: fallback,
                    uiImage: base,
                    timestamp: Date(),
                    imageFilename: nil
                )
                libraryVM.addPoster(item)
                phase = 3
            }
        }
    }
    
    private func resetState() {
        query = ""
        selectedYear = ""
        userRating = 5
        dateWatched = ""
        phase = 0
        results = []
        posterImages = []
        chosenPoster = nil
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
