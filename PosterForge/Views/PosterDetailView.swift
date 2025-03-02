import SwiftUI
import UIKit

/// Wrapper per mostrare lo UIActivityViewController in SwiftUI
struct ActivityViewControllerWrapper: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Non serve alcun update runtime
    }
}

struct PosterDetailView: View, Identifiable {
    var id: UUID { posterItem.id }

    let posterItem: PosterItem
    @EnvironmentObject var libraryVM: LibraryViewModel

    @State private var generatedPoster: UIImage?
    @State private var showingShareSheet = false

    // Aggiungiamo uno stato per la full-screen con l’immagine generata
    @State private var showGeneratedFullScreen = false

    var body: some View {
        NavigationView {
            VStack {
                posterItem.image
                    .resizable()
                    .scaledToFit()
                    .padding()

                Text(posterItem.movie.title)
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Anno: \(posterItem.movie.year)")
                Text("Voto: \(posterItem.movie.rating)/10")
                Text("Data visione: \(posterItem.movie.dateWatched)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider().padding()

                Spacer()

                HStack {
                    Button("Crea Poster Tradizionale") {
                        generatePoster(layout: "traditional")
                    }
                    .padding()

                    Button("Crea Poster Moderno") {
                        generatePoster(layout: "modern")
                    }
                    .padding()
                }
            }
            .navigationTitle("Dettagli Poster")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showGeneratedFullScreen) {
                if let g = generatedPoster {
                    FullScreenPosterView(
                        uiImage: g,
                        onClose: { showGeneratedFullScreen = false }
                    )
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func generatePoster(layout: String) {
        guard let baseImage = posterItem.uiImage else { return }
        if let newImg = PosterGenerator.shared.generatePoster(
            baseImage: baseImage,
            layout: layout,
            movie: posterItem.movie
        ) {
            self.generatedPoster = newImg
            self.showGeneratedFullScreen = true
        }
    }
}

// Una vista full-screen per mostrare il poster generato
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
            .navigationBarItems(trailing:
                Button("Chiudi") {
                    onClose()
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
