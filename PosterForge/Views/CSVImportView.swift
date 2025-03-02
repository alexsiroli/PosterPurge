import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var preferencesManager: PreferencesManager
    @ObservedObject var libraryVM: LibraryViewModel

    @State private var showDocumentPicker = false
    @State private var isProcessing = false
    @State private var progressText = "Seleziona un CSV..."

    @State private var pendingMovies: [MovieModel] = []
    @State private var currentIndex = 0
    @State private var posterImages: [UIImage] = []
    @State private var chosenPoster: UIImage?
    @State private var showingManualSheet = false
    
    // "Sbagliato film" sheet
    @State private var showingWrongFilmSheet = false
    @State private var searchResults: [TMDbService.TMDbSearchResult] = []
    @State private var searchQuery = ""
    @State private var isTV = false
    @State private var yearGuess: Int? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(progressText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()

                if !isProcessing && pendingMovies.isEmpty {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Text("Scegli file CSV")
                            .font(.title3)
                            .padding()
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Import CSV")
            .navigationBarItems(leading: Button("Chiudi") {
                presentationMode.wrappedValue.dismiss()
            })
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .sheet(isPresented: $showingManualSheet) {
                manualSelectionSheet()
            }
            .sheet(isPresented: $showingWrongFilmSheet) {
                wrongFilmSheet()
            }
        }
    }

    // MARK: - Import CSV
    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importCSV(from: url)
        case .failure(let e):
            print("ERRORE selezione file CSV:", e.localizedDescription)
        }
    }

    func importCSV(from url: URL) {
        isProcessing = true
        progressText = "Caricamento CSV..."

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var isAccessing = false
                if url.startAccessingSecurityScopedResource() {
                    isAccessing = true
                }
                defer {
                    if isAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let csvString = try String(contentsOf: url, encoding: .utf8)
                let sanitized = csvString.replacingOccurrences(of: "\"", with: "")
                let movies = CSVParser.parseMovies(from: sanitized)
                if movies.isEmpty {
                    DispatchQueue.main.async {
                        self.progressText = "Nessun film trovato nel CSV."
                        self.isProcessing = false
                    }
                    return
                }
                let existing = Set(self.libraryVM.posters.map { $0.movie.normalizedTitle })
                let newMovs = movies.filter { !existing.contains($0.normalizedTitle) }
                DispatchQueue.main.async {
                    self.startImportProcess(movies: newMovs)
                }
            } catch {
                DispatchQueue.main.async {
                    self.progressText = "Errore lettura CSV"
                    self.isProcessing = false
                }
            }
        }
    }

    private func startImportProcess(movies: [MovieModel]) {
        guard !movies.isEmpty else {
            progressText = "CSV import: Nessun film nuovo da importare."
            isProcessing = false
            return
        }
        let mode = preferencesManager.preferences.posterSelectionMode
        if mode == "automatic" {
            Task { await importAutomatically(movies: movies) }
        } else {
            self.pendingMovies = movies
            self.currentIndex = 0
            showNextManualStep()
        }
    }

    // MARK: - Automatic
    private func importAutomatically(movies: [MovieModel]) async {
        progressText = "Inizio import automatico (\(movies.count) film)..."
        isProcessing = true
        var processedCount = 0
        for mov in movies {
            let yInt = Int(mov.year).flatMap { $0 == 0 ? nil : $0 }
            do {
                let results = try await TMDbService.shared.search(
                    query: mov.title,
                    mediaType: mov.isTV ? .tv : .movie,
                    year: yInt
                )
                if let first = results.first {
                    // fetch images
                    let imgResp = try await TMDbService.shared.fetchImages(for: first.id, mediaType: mov.isTV ? .tv : .movie)
                    let posters = imgResp.posters.prefix(50)
                    if let bestPoster = posters.first,
                       let downloaded = try await TMDbService.shared.downloadImage(path: bestPoster.file_path) {
                        
                        // Carichiamo i dettagli in italiano (title e year corretti)
                        let details = try await fetchTMDbDetails(itemID: first.id, isTV: mov.isTV)
                        // Creiamo il MovieModel con i dati “title” e “year” da TMDb
                        let finalMovie = MovieModel(
                            title: details.title,
                            year: details.year,
                            rating: mov.rating,
                            dateWatched: mov.dateWatched,
                            isTV: mov.isTV
                        )
                        let item = PosterItem(
                            id: UUID(),
                            movie: finalMovie,
                            uiImage: downloaded,
                            timestamp: Date(),
                            imageFilename: nil
                        )
                        libraryVM.addPoster(item)
                    }
                }
            } catch {
                print("Errore (import automatico) su \"\(mov.title)\": \(error.localizedDescription)")
            }
            processedCount += 1
            progressText = "Generati \(processedCount)/\(movies.count)"
        }
        progressText = "Import automatico completato!"
        isProcessing = false
    }

    // MARK: - Manual
    private func showNextManualStep() {
        guard currentIndex < pendingMovies.count else {
            progressText = "Import manuale completato!"
            isProcessing = false
            return
        }
        isProcessing = true
        let mov = pendingMovies[currentIndex]
        // Catturiamo l'identificatore univoco del film (ad es. il titolo normalizzato)
        let currentMovieIdentifier = mov.normalizedTitle
        progressText = "Cerco: \(mov.title)..."

        let yInt = Int(mov.year).flatMap { $0 == 0 ? nil : $0 }
        Task {
            do {
                let results = try await TMDbService.shared.search(
                    query: mov.title,
                    mediaType: mov.isTV ? .tv : .movie,
                    year: yInt
                )
                if let first = results.first {
                    let imgResp = try await TMDbService.shared.fetchImages(for: first.id, mediaType: mov.isTV ? .tv : .movie)
                    let subset = imgResp.posters.prefix(50)
                    // Presenta subito il foglio manuale con array vuoto, ma solo se il film corrente è ancora valido
                    await MainActor.run {
                        if currentIndex < pendingMovies.count,
                           pendingMovies[currentIndex].normalizedTitle == currentMovieIdentifier {
                            posterImages = []
                            isProcessing = false
                            progressText = "Seleziona poster per \(mov.title)"
                            showingManualSheet = true
                        }
                    }
                    // Scarica e aggiungi le immagini progressivamente, controllando sempre che il film corrente sia lo stesso
                    for p in subset {
                        if let downloaded = try await TMDbService.shared.downloadImage(path: p.file_path) {
                            await MainActor.run {
                                if currentIndex < pendingMovies.count,
                                   pendingMovies[currentIndex].normalizedTitle == currentMovieIdentifier {
                                    posterImages.append(downloaded)
                                }
                            }
                        }
                    }
                } else {
                    await MainActor.run {
                        isProcessing = false
                        finishCurrentMovie(nil)
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    finishCurrentMovie(nil)
                }
            }
        }
    }

    @ViewBuilder
    private func manualSelectionSheet() -> some View {
        let mov = pendingMovies[currentIndex]
        VStack {
            Text("Scegli Poster per \(mov.title)")
                .font(.headline)
                .padding()

            if posterImages.isEmpty {
                Text("Nessuna locandina trovata.")
                    .padding()
                Button("Avanti") {
                    showingManualSheet = false
                    finishCurrentMovie(nil)
                }
                Button("Film sbagliato") {
                    showingManualSheet = false
                    self.searchQuery = mov.title
                    self.isTV = mov.isTV
                    if let y = Int(mov.year), y != 0 {
                        yearGuess = y
                    } else {
                        yearGuess = nil
                    }
                    showingWrongFilmSheet = true
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(0..<posterImages.count, id: \.self) { i in
                            Button {
                                chosenPoster = posterImages[i]
                                showingManualSheet = false
                                finishCurrentMovie(chosenPoster)
                            } label: {
                                Image(uiImage: posterImages[i])
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                    }
                    .padding()
                }
                Button("Film sbagliato") {
                    showingManualSheet = false
                    self.searchQuery = mov.title
                    self.isTV = mov.isTV
                    if let y = Int(mov.year), y != 0 {
                        yearGuess = y
                    } else {
                        yearGuess = nil
                    }
                    showingWrongFilmSheet = true
                }
                .padding(.top, 12)
            }
        }
        .padding()
    }

    private func finishCurrentMovie(_ chosen: UIImage?) {
        let mov = pendingMovies[currentIndex]
        if let img = chosen {
            // Carichiamo i dati TMDb in italiano
            Task {
                do {
                    // Cerchiamo nuovamente, prendiamo il primo
                    let yInt = Int(mov.year).flatMap { $0 == 0 ? nil : $0 }
                    let results = try await TMDbService.shared.search(
                        query: mov.title,
                        mediaType: mov.isTV ? .tv : .movie,
                        year: yInt
                    )
                    if let first = results.first {
                        let details = try await fetchTMDbDetails(itemID: first.id, isTV: mov.isTV)
                        let finalMovie = MovieModel(
                            title: details.title,
                            year: details.year,
                            rating: mov.rating,
                            dateWatched: mov.dateWatched,
                            isTV: mov.isTV
                        )
                        let item = PosterItem(
                            id: UUID(),
                            movie: finalMovie,
                            uiImage: img,
                            timestamp: Date(),
                            imageFilename: nil
                        )
                        await MainActor.run {
                            libraryVM.addPoster(item)
                        }
                    } else {
                        // fallback, non trovato
                        let item = PosterItem(
                            id: UUID(),
                            movie: mov,
                            uiImage: img,
                            timestamp: Date(),
                            imageFilename: nil
                        )
                        await MainActor.run {
                            libraryVM.addPoster(item)
                        }
                    }
                } catch {
                    let item = PosterItem(
                        id: UUID(),
                        movie: mov,
                        uiImage: img,
                        timestamp: Date(),
                        imageFilename: nil
                    )
                    await MainActor.run {
                        libraryVM.addPoster(item)
                    }
                }
            }
        }
        currentIndex += 1
        showNextManualStep()
    }

    // MARK: - WrongFilmSheet
    @ViewBuilder
    private func wrongFilmSheet() -> some View {
        NavigationView {
            VStack {
                TextField("Nome Film/Serie", text: $searchQuery)
                    .padding()
                Toggle("È una Serie TV?", isOn: $isTV)
                    .padding(.horizontal)
                HStack {
                    Text("Anno (opzionale):")
                    TextField("Es: 2023", value: $yearGuess, format: .number)
                        .keyboardType(.numberPad)
                }
                .padding(.horizontal)

                Button("Cerca su TMDb") {
                    Task { await doManualSearch() }
                }
                .padding()

                if searchResults.isEmpty {
                    Text("Nessun risultato.").padding()
                } else {
                    List {
                        ForEach(searchResults, id: \.id) { r in
                            Button {
                                pickSearchResult(r)
                            } label: {
                                let name = isTV ? (r.name ?? "") : (r.title ?? "")
                                let y = isTV ? r.first_air_date : r.release_date
                                Text("\(name) (\(y?.prefix(4) ?? "????"))")
                            }
                        }
                    }
                }
                Spacer()
            }
            .navigationBarItems(trailing:
                Button("Chiudi") {
                    showingWrongFilmSheet = false
                }
            )
            .navigationTitle("Scegli Film Corretto")
        }
    }

    private func pickSearchResult(_ r: TMDbService.TMDbSearchResult) {
        let mov = pendingMovies[currentIndex]
        // Catturiamo l'identificatore del film corrente
        let currentMovieIdentifier = mov.normalizedTitle
        showingWrongFilmSheet = false
        isProcessing = true
        progressText = "Carico locandine alternative..."

        Task {
            do {
                let imgResp = try await TMDbService.shared.fetchImages(for: r.id, mediaType: mov.isTV ? .tv : .movie)
                let subset = imgResp.posters.prefix(50)
                await MainActor.run {
                    if currentIndex < pendingMovies.count,
                       pendingMovies[currentIndex].normalizedTitle == currentMovieIdentifier {
                        posterImages = []
                        isProcessing = false
                        showingManualSheet = true
                        progressText = "Seleziona poster per \(mov.title)"
                    }
                }
                for p in subset {
                    if let downloaded = try await TMDbService.shared.downloadImage(path: p.file_path) {
                        await MainActor.run {
                            if currentIndex < pendingMovies.count,
                               pendingMovies[currentIndex].normalizedTitle == currentMovieIdentifier {
                                posterImages.append(downloaded)
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    finishCurrentMovie(nil)
                }
            }
        }
    }

    private func doManualSearch() async {
        searchResults = []
        guard !searchQuery.isEmpty else { return }
        let type = isTV ? TMDbService.MediaType.tv : .movie
        do {
            let arr = try await TMDbService.shared.search(query: searchQuery, mediaType: type, year: yearGuess)
            self.searchResults = arr
        } catch {
            print("Errore manual search: \(error.localizedDescription)")
        }
    }

    // MARK: - Funzione per caricare i dettagli (title+year) in italiano
    private func fetchTMDbDetails(itemID: Int, isTV: Bool) async throws -> (title: String, year: String) {
        if isTV {
            let urlString = "https://api.themoviedb.org/3/tv/\(itemID)?api_key=\(TMDbService.shared.apiKey)&language=it-IT"
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }
            let (data, _) = try await URLSession.shared.data(from: url)
            let info = try JSONDecoder().decode(TVDetails.self, from: data)
            let name = info.name.isEmpty ? (info.original_name ?? "??") : info.name
            let first = info.first_air_date ?? ""
            let year = first.count >= 4 ? String(first.prefix(4)) : "????"
            return (name, year)
        } else {
            let urlString = "https://api.themoviedb.org/3/movie/\(itemID)?api_key=\(TMDbService.shared.apiKey)&language=it-IT"
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }
            let (data, _) = try await URLSession.shared.data(from: url)
            let info = try JSONDecoder().decode(MovieDetails.self, from: data)
            let title = info.title.isEmpty ? (info.original_title ?? "??") : info.title
            let rd = info.release_date ?? ""
            let year = rd.count >= 4 ? String(rd.prefix(4)) : "????"
            return (title, year)
        }
    }
}
