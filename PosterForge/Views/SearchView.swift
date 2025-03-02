// ========================================
// File: SearchView.swift
// ========================================
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

    @State private var selectedItem: TMDbService.TMDbSearchResult?
    @State private var posterImages: [UIImage] = []
    @State private var chosenPoster: UIImage?

    // 0: inserimento query
    // 1: mostra risultati
    // 2: mostra poster
    // 3: completato
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
            .onAppear {
                resetState()
            }
        }
    }

    // MARK: - UI Fasi
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
                Button("Cerca") {
                    search()
                }
            }
        }
    }

    @ViewBuilder
    private func phase1View() -> some View {
        VStack {
            if results.isEmpty {
                Text("Nessun risultato trovato.")
                    .padding()
            } else {
                List(results, id: \.id) { item in
                    Button {
                        handleResultSelection(item: item)
                    } label: {
                        Text(displayTitle(for: item))
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
                    ForEach(0 ..< posterImages.count, id: \.self) { i in
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

    // MARK: - Logica di ricerca
    private func search() {
        phase = 1
        results = []
        posterImages = []
        chosenPoster = nil

        Task {
            do {
                let yearInt = Int(selectedYear)
                results = try await TMDbService.shared.search(
                    query: query,
                    mediaType: isTV ? .tv : .movie,
                    year: yearInt
                )
            } catch {
                print("Errore ricerca: \(error.localizedDescription)")
            }
        }
    }

    private func handleResultSelection(item: TMDbService.TMDbSearchResult) {
        selectedItem = item
        let yearString = isTV ? item.first_air_date : item.release_date
        if let yearString = yearString, yearString.count >= 4, selectedYear.isEmpty {
            selectedYear = String(yearString.prefix(4))
        }
        fetchPosters(for: item)
    }

    private func fetchPosters(for item: TMDbService.TMDbSearchResult) {
        Task {
            do {
                let imagesResponse = try await TMDbService.shared.fetchImages(
                    for: item.id,
                    mediaType: isTV ? .tv : .movie
                )
                
                var images: [UIImage] = []
                for poster in imagesResponse.posters.prefix(30) {
                    if let image = try await TMDbService.shared.downloadImage(path: poster.file_path) {
                        images.append(image)
                    }
                }

                await MainActor.run {
                    posterImages = images
                    phase = 2
                }
            } catch {
                print("Errore fetch poster: \(error.localizedDescription)")
                await MainActor.run {
                    phase = 0
                }
            }
        }
    }

    private func generateFinalPoster() {
        guard let base = chosenPoster else { return }
        let movie = MovieModel(
            title: query,
            year: selectedYear,
            rating: userRating,
            dateWatched: dateWatched,
            isTV: isTV
        )
        let item = PosterItem(
            id: UUID(),
            movie: movie,
            uiImage: base,
            timestamp: Date(),
            imageFilename: nil
        )
        libraryVM.addPoster(item)
        phase = 3
    }

    // MARK: - Helper
    private func displayTitle(for item: TMDbService.TMDbSearchResult) -> String {
        let title = item.displayTitle
        let year = item.releaseYear
        return "\(title) (\(year))"
    }

    private func resetState() {
        query = ""
        selectedYear = ""
        userRating = 5
        dateWatched = ""
        phase = 0
    }
}
