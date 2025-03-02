// ========================================
// File: LibraryView.swift
// ========================================
import SwiftUI

struct LibraryView: View {
    @ObservedObject var libraryVM: LibraryViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedPosterItem: PosterItem?
    @State private var showingDetail = false

    // Multi-selezione
    @State private var selectionMode = false
    @State private var selectedItems: Set<UUID> = []

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            VStack {
                if libraryVM.posters.isEmpty {
                    Text("La tua libreria è vuota.\nImporta un CSV o cerca un film!")
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(sortedPosters) { poster in
                                LibraryPosterCell(
                                    poster: poster,
                                    isSelected: selectionMode && selectedItems.contains(poster.id)
                                ) {
                                    if selectionMode {
                                        toggleSelection(poster.id)
                                    } else {
                                        selectedPosterItem = poster
                                        showingDetail = true
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }

                if selectionMode && !selectedItems.isEmpty {
                    // Pulsante per scaricare in blocco
                    Button("Scarica selezionati") {
                        showLayoutChoiceForMultiple()
                    }
                    .padding()
                }
            }
            .navigationTitle("La mia Libreria")
            .navigationBarItems(
                leading: Button("Chiudi") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(selectionMode ? "Fine" : "Seleziona") {
                    selectionMode.toggle()
                    if !selectionMode {
                        selectedItems.removeAll()
                    }
                }
            )
            .sheet(item: $selectedPosterItem) { item in
                PosterDetailView(posterItem: item)
                    .environmentObject(libraryVM)
            }
        }
    }

    var sortedPosters: [PosterItem] {
        // Dal più recente al meno recente
        libraryVM.posters.sorted { $0.timestamp > $1.timestamp }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }

    private func showLayoutChoiceForMultiple() {
        // Mostra un'ActionSheet con scelta layout
        let alert = UIAlertController(title: "Scegli layout", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Tradizionale", style: .default, handler: { _ in
            generateAndSaveMultiple(layout: "traditional")
        }))
        alert.addAction(UIAlertAction(title: "Moderno", style: .default, handler: { _ in
            generateAndSaveMultiple(layout: "modern")
        }))
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel, handler: nil))

        // Per presentare un UIAlertController in SwiftUI:
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(alert, animated: true, completion: nil)
        }
    }

    private func generateAndSaveMultiple(layout: String) {
        for poster in sortedPosters where selectedItems.contains(poster.id) {
            guard let baseImage = poster.uiImage else { continue }
            if let newImg = PosterGenerator.shared.generatePoster(
                baseImage: baseImage,
                layout: layout,
                movie: poster.movie
            ) {
                UIImageWriteToSavedPhotosAlbum(newImg, nil, nil, nil)
            }
        }
        selectedItems.removeAll()
        selectionMode = false
    }
}

struct LibraryPosterCell: View {
    let poster: PosterItem
    let isSelected: Bool
    let tapAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            poster.image
                .resizable()
                .scaledToFit()
                .cornerRadius(8)
                .shadow(radius: 2)
                .onTapGesture {
                    tapAction()
                }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .padding(5)
            }
        }
        .overlay(
            Text("\(poster.movie.title) (\(poster.movie.year))")
                .font(.caption)
                .padding(4)
                .background(Color.black.opacity(0.5))
                .foregroundColor(.white)
            ,
            alignment: .bottom
        )
    }
}
