import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var preferencesManager: PreferencesManager
    @ObservedObject var libraryVM: LibraryViewModel

    @State private var showDocumentPicker = false
    @State private var isProcessing = false
    @State private var progressText = "Seleziona un CSV..."

    // Gestione manuale
    @State private var pendingMovies: [MovieModel] = []
    @State private var currentIndex = 0
    @State private var posterImages: [UIImage] = []
    @State private var chosenPoster: UIImage?
    @State private var showingManualSheet = false

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
            // Foglio di selezione "manuale"
            .sheet(isPresented: $showingManualSheet, content: {
                manualSelectionSheet()
            })
        }
    }

    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importCSV(from: url)
        case .failure(let error):
            print("Errore selezione file: \(error)")
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
                let movies = CSVParser.parseMovies(from: csvString)

                if movies.isEmpty {
                    DispatchQueue.main.async {
                        self.progressText = "Nessun film trovato nel CSV."
                        self.isProcessing = false
                    }
                    return
                }

                let existingTitles = Set(self.libraryVM.posters.map { $0.movie.normalizedTitle })
                let newMovies = movies.filter { !existingTitles.contains($0.normalizedTitle) }

                DispatchQueue.main.async {
                    self.startImportProcess(movies: newMovies)
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
            // Comportamento classico
            Task {
                await importAutomatically(movies: movies)
            }
        } else {
            // Manuale: popoliamo pendingMovies e avviamo la selezione step by step
            self.pendingMovies = movies
            self.currentIndex = 0
            showNextManualStep()
        }
    }

    // MARK: - Import Automatico
    private func importAutomatically(movies: [MovieModel]) async {
        progressText = "Inizio import automatico (\(movies.count) film)..."
        isProcessing = true
        let userPref = preferencesManager.preferences

        var processedCount = 0
        for m in movies {
            let yearInt = Int(m.year).flatMap { $0 == 0 ? nil : $0 }
            let group = DispatchGroup()
            var chosenPoster: UIImage?
            group.enter()

            TMDbService.shared.search(query: m.title, isTV: m.isTV, year: yearInt) { results in
                if let firstResult = results.first {
                    TMDbService.shared.fetchPosters(
                        itemID: firstResult.id,
                        isTV: m.isTV,
                        languagePref: userPref.preferredLanguage
                    ) { posterInfos in
                        if let firstPoster = posterInfos.first {
                            TMDbService.shared.downloadPoster(path: firstPoster.file_path) { img in
                                chosenPoster = img
                                group.leave()
                            }
                        } else {
                            group.leave()
                        }
                    }
                } else {
                    group.leave()
                }
            }

            group.wait()

            if let basePoster = chosenPoster {
                let item = PosterItem(
                    id: UUID(),
                    movie: m,
                    uiImage: basePoster,
                    timestamp: Date(),
                    imageFilename: nil
                )
                libraryVM.addPoster(item)
            }
            processedCount += 1
            progressText = "Generati \(processedCount) / \(movies.count)"
        }

        progressText = "Import automatico completato!"
        isProcessing = false
    }

    // MARK: - Import Manuale
    // Step by step. Scarichiamo i poster per pendingMovies[currentIndex], mostriamo la sheet, l'utente sceglie
    private func showNextManualStep() {
        guard currentIndex < pendingMovies.count else {
            // Finito
            progressText = "Import manuale completato!"
            isProcessing = false
            return
        }
        isProcessing = true
        progressText = "Ricerca poster per \(pendingMovies[currentIndex].title)..."

        let m = pendingMovies[currentIndex]
        let userPref = preferencesManager.preferences
        let yearInt = Int(m.year).flatMap { $0 == 0 ? nil : $0 }

        // Ricerca
        TMDbService.shared.search(query: m.title, isTV: m.isTV, year: yearInt) { results in
            if let firstResult = results.first {
                TMDbService.shared.fetchPosters(
                    itemID: firstResult.id,
                    isTV: m.isTV,
                    languagePref: userPref.preferredLanguage
                ) { posterInfos in
                    if posterInfos.isEmpty {
                        // Nessun poster, passiamo al prossimo
                        self.finishCurrentMovie(nil)
                        return
                    }
                    // Scarichiamo i primi max 15
                    let subset = Array(posterInfos.prefix(15))
                    self.downloadImages(for: subset, movie: m)
                }
            } else {
                // Nessun result TMDb
                self.finishCurrentMovie(nil)
            }
        }
    }

    private func downloadImages(for posters: [TMDbImageInfo], movie: MovieModel) {
        var images: [UIImage] = []
        let group = DispatchGroup()

        for p in posters {
            group.enter()
            TMDbService.shared.downloadPoster(path: p.file_path) { img in
                if let i = img {
                    images.append(i)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.posterImages = images
            self.isProcessing = false
            self.progressText = "Seleziona poster per \(movie.title)"
            self.showingManualSheet = true
        }
    }

    @ViewBuilder
    private func manualSelectionSheet() -> some View {
        VStack {
            Text("Scegli Poster per \(pendingMovies[currentIndex].title)")
                .font(.headline)
                .padding()

            if posterImages.isEmpty {
                Text("Nessuna locandina trovata.")
                    .padding()
                Button("Avanti") {
                    // Fine step
                    self.showingManualSheet = false
                    finishCurrentMovie(nil)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(0 ..< posterImages.count, id: \.self) { i in
                            Button {
                                chosenPoster = posterImages[i]
                                // Fine step
                                self.showingManualSheet = false
                                finishCurrentMovie(chosenPoster)
                            } label: {
                                Image(uiImage: posterImages[i])
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func finishCurrentMovie(_ poster: UIImage?) {
        // Salviamo
        let m = pendingMovies[currentIndex]
        if let p = poster {
            let item = PosterItem(
                id: UUID(),
                movie: m,
                uiImage: p,
                timestamp: Date(),
                imageFilename: nil
            )
            libraryVM.addPoster(item)
        }

        currentIndex += 1
        if currentIndex < pendingMovies.count {
            // Passiamo al film successivo
            showNextManualStep()
        } else {
            progressText = "Import manuale completato!"
            isProcessing = false
        }
    }
}
