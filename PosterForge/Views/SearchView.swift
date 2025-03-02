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
    @State private var results: [TMDbSearchResult] = []

    @State private var selectedYear = ""
    @State private var userRating = 5
    @State private var dateWatched = ""

    @State private var selectedItem: TMDbSearchResult?
    @State private var posterImages: [UIImage] = []
    @State private var chosenPoster: UIImage?

    // 0: inserimento query
    // 1: mostra risultati
    // 2: mostra poster
    // 3: completato
    @State private var phase = 0

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            Group {
                if phase == 0 {
                    phase0View()
                } else if phase == 1 {
                    phase1View()
                } else if phase == 2 {
                    phase2View()
                } else {
                    phase3View()
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

    // MARK: - Fase 0
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

    // MARK: - Fase 1
    private func phase1View() -> some View {
        VStack {
            if results.isEmpty {
                Text("Nessun risultato trovato.")
                    .padding()
            } else {
                List(results, id: \.id) { item in
                    Button {
                        // Quando l'utente seleziona un risultato, se non abbiamo specificato un anno manualmente
                        // prendiamo l'anno dal "release_date" o "first_air_date"
                        self.selectedItem = item
                        let yearString = isTV ? (item.first_air_date ?? "") : (item.release_date ?? "")
                        if yearString.count >= 4 && self.selectedYear.isEmpty {
                            self.selectedYear = String(yearString.prefix(4))
                        }

                        fetchPosters(for: item)
                    } label: {
                        Text(displayTitle(for: item))
                    }
                }
            }
        }
    }

    // MARK: - Fase 2
    private func phase2View() -> some View {
        VStack {
            Text("Scegli Poster")
                .font(.headline)
                .padding()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(0 ..< posterImages.count, id: \.self) { i in
                        Button(action: {
                            self.chosenPoster = posterImages[i]
                            generateFinalPoster()
                        }) {
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

    // MARK: - Fase 3
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

    // MARK: - Ricerca
    func search() {
        results = []
        posterImages = []
        chosenPoster = nil
        phase = 1

        let yearInt = Int(selectedYear)
        TMDbService.shared.search(query: query, isTV: isTV, year: yearInt) { res in
            self.results = res
        }
    }

    // MARK: - Caricamento poster
    func fetchPosters(for item: TMDbSearchResult) {
        let userPref = preferencesManager.preferences
        TMDbService.shared.fetchPosters(
            itemID: item.id,
            isTV: isTV,
            languagePref: userPref.preferredLanguage
        ) { posters in
            let maxToShow = min(30, posters.count)
            let subset = Array(posters.prefix(maxToShow))

            self.posterImages = []
            let group = DispatchGroup()

            for p in subset {
                group.enter()
                TMDbService.shared.downloadPoster(path: p.file_path) { img in
                    if let i = img {
                        self.posterImages.append(i)
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.phase = 2
            }
        }
    }

    // MARK: - Genera e salva locandina base
    func generateFinalPoster() {
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
    private func displayTitle(for item: TMDbSearchResult) -> String {
        let title = isTV ? (item.name ?? "??") : (item.title ?? "??")
        let yearString = isTV ? (item.first_air_date ?? "") : (item.release_date ?? "")
        var finalYear = "????"
        if yearString.count >= 4 {
            finalYear = String(yearString.prefix(4))
        }
        return "\(title) (\(finalYear))"
    }

    private func resetState() {
        query = ""
        selectedYear = ""
        userRating = 5
        dateWatched = ""
        phase = 0
    }
}
