// ========================================
// File: CSVImportView.swift
// ========================================
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
            print("ERRORE selezione file CSV:", error.localizedDescription)
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
            Task {
                await importAutomatically(movies: movies)
            }
        } else {
            self.pendingMovies = movies
            self.currentIndex = 0
            showNextManualStep()
        }
    }

    // MARK: - Import Automatico
    private func importAutomatically(movies: [MovieModel]) async {
        progressText = "Inizio import automatico (\(movies.count) film)..."
        isProcessing = true

        var processedCount = 0
        for m in movies {
            let yearInt = Int(m.year).flatMap { $0 == 0 ? nil : $0 }
            do {
                let results = try await TMDbService.shared.search(
                    query: m.title,
                    mediaType: m.isTV ? .tv : .movie,
                    year: yearInt
                )

                if let firstResult = results.first {
                    let imagesResponse = try await TMDbService.shared.fetchImages(
                        for: firstResult.id,
                        mediaType: m.isTV ? .tv : .movie
                    )

                    if let firstPoster = imagesResponse.posters.first,
                       let image = try await TMDbService.shared.downloadImage(path: firstPoster.file_path) {

                        let item = PosterItem(
                            id: UUID(),
                            movie: m,
                            uiImage: image,
                            timestamp: Date(),
                            imageFilename: nil
                        )
                        libraryVM.addPoster(item)
                    }
                }

            } catch {
                // Se fallisce la ricerca o il download, lo skippo.
                // Possiamo stampare un log di errore o ignorare
                print("Errore (import automatico) su \"\(m.title)\": \(error.localizedDescription)")
            }

            processedCount += 1
            progressText = "Generati \(processedCount) / \(movies.count)"
        }

        progressText = "Import automatico completato!"
        isProcessing = false
    }

    // MARK: - Import Manuale
    private func showNextManualStep() {
        guard currentIndex < pendingMovies.count else {
            progressText = "Import manuale completato!"
            isProcessing = false
            return
        }

        isProcessing = true
        progressText = "Ricerca poster per \(pendingMovies[currentIndex].title)..."

        let m = pendingMovies[currentIndex]
        let yearInt = Int(m.year).flatMap { $0 == 0 ? nil : $0 }

        Task {
            do {
                let results = try await TMDbService.shared.search(
                    query: m.title,
                    mediaType: m.isTV ? .tv : .movie,
                    year: yearInt
                )

                if let firstResult = results.first {
                    let imagesResponse = try await TMDbService.shared.fetchImages(
                        for: firstResult.id,
                        mediaType: m.isTV ? .tv : .movie
                    )
                    let posters = imagesResponse.posters.prefix(15)
                    await downloadImages(for: Array(posters))
                } else {
                    finishCurrentMovie(nil)
                }
            } catch {
                finishCurrentMovie(nil)
            }
        }
    }

    private func downloadImages(for posters: [TMDbService.TMDbImageInfo]) async {
        var images: [UIImage] = []

        for poster in posters {
            do {
                if let image = try await TMDbService.shared.downloadImage(path: poster.file_path) {
                    images.append(image)
                }
            } catch {
                // Se vuoi puoi stampare log
            }
        }

        await MainActor.run {
            posterImages = images
            isProcessing = false
            progressText = "Seleziona poster per \(pendingMovies[currentIndex].title)"
            showingManualSheet = true
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
                    showingManualSheet = false
                    finishCurrentMovie(nil)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(0 ..< posterImages.count, id: \.self) { i in
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
                }
            }
        }
        .padding()
    }

    private func finishCurrentMovie(_ poster: UIImage?) {
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
            showNextManualStep()
        } else {
            progressText = "Import manuale completato!"
            isProcessing = false
        }
    }
}
