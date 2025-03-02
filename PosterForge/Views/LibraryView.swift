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
                    HStack(spacing: 40) {
                        Button("Scarica selezionati") {
                            showLayoutChoiceForMultiple()
                        }
                        Button("Elimina selezionati") {
                            removeSelectedPosters()
                        }
                    }
                    .padding(.bottom, 20)
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
        libraryVM.posters.sorted { $0.timestamp > $1.timestamp }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }

    private func removeSelectedPosters() {
        let toRemove = sortedPosters.filter{selectedItems.contains($0.id)}
        for p in toRemove {
            libraryVM.removePoster(p)
        }
        selectedItems.removeAll()
        selectionMode=false
    }

    private func showLayoutChoiceForMultiple() {
        let alert = UIAlertController(
            title:"Operazione",
            message:"Come vuoi scaricare i poster selezionati?",
            preferredStyle:.actionSheet
        )
        alert.addAction(UIAlertAction(title:"Poster grezzo", style:.default, handler:{ _ in
            downloadMultipleRaw()
        }))
        alert.addAction(UIAlertAction(title:"Layout Tradizionale", style:.default, handler:{ _ in
            generateAndSaveMultiple(layout:"traditional")
        }))
        alert.addAction(UIAlertAction(title:"Layout Moderno", style:.default, handler:{ _ in
            generateAndSaveMultiple(layout:"modern")
        }))
        alert.addAction(UIAlertAction(title:"Annulla", style:.cancel, handler:nil))

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window=scene.windows.first,
           let root=window.rootViewController {
            
            if let pop = alert.popoverPresentationController {
                pop.sourceView=window
                pop.sourceRect=CGRect(x: window.bounds.midX, y: window.bounds.maxY, width:0,height:0)
                pop.permittedArrowDirections=[]
            }
            root.present(alert, animated:true)
        }
    }

    private func downloadMultipleRaw() {
        for p in sortedPosters where selectedItems.contains(p.id) {
            if let base=p.uiImage {
                UIImageWriteToSavedPhotosAlbum(base, nil, nil, nil)
            }
        }
        selectedItems.removeAll()
        selectionMode=false
    }

    private func generateAndSaveMultiple(layout:String) {
        for p in sortedPosters where selectedItems.contains(p.id) {
            guard let base=p.uiImage else{continue}
            if let newImg = PosterGenerator.shared.generatePoster(baseImage:base, layout:layout, movie:p.movie){
                UIImageWriteToSavedPhotosAlbum(newImg, nil, nil, nil)
            }
        }
        selectedItems.removeAll()
        selectionMode=false
    }
}

struct LibraryPosterCell: View {
    let poster: PosterItem
    let isSelected: Bool
    let tapAction: ()->Void

    var body: some View {
        ZStack(alignment:.topTrailing) {
            poster.image
                .resizable()
                .scaledToFit()
                .cornerRadius(8)
                .shadow(radius:2)
                .onTapGesture{ tapAction() }

            if isSelected {
                Image(systemName:"checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .padding(5)
            }
        }
        .overlay(
            Text("\(poster.movie.title) (\(poster.movie.year))")
                .font(.caption)
                .padding(4)
                .background(Color.black.opacity(0.5))
                .foregroundColor(.white),
            alignment: .bottom
        )
    }
}
