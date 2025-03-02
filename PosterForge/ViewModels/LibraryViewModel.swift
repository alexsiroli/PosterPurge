import SwiftUI

class LibraryViewModel: ObservableObject {
    @Published var posters: [PosterItem] = []

    private let libraryKey = "PosterForgeLibrary"
    private let folderName = "PosterForgeImages"

    init() {
        loadLibrary()
        // Ascoltiamo la notifica di reset
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLibraryReset),
            name: .libraryResetRequested,
            object: nil
        )
    }

    @objc private func handleLibraryReset() {
        // Rimuoviamo tutti i file e svuotiamo l'array
        for p in posters {
            deleteImageFromDisk(poster: p)
        }
        posters.removeAll()

        // Cancelliamo pure il file JSON
        let jsonURL = libraryURL()
        do {
            if FileManager.default.fileExists(atPath: jsonURL.path) {
                try FileManager.default.removeItem(at: jsonURL)
            }
        } catch {
            print("Errore eliminando library JSON:", error)
        }

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    // MARK: - Aggiunta/Rimozione Poster
    func addPoster(_ poster: PosterItem) {
        posters.append(poster)
        saveLibrary()
    }

    func removePoster(_ poster: PosterItem) {
        posters.removeAll { $0.id == poster.id }
        deleteImageFromDisk(poster: poster)
        saveLibrary()
    }

    // MARK: - Salvataggio Libreria su Disco
    func saveLibrary() {
        do {
            let folderURL = imagesFolderURL()
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            }

            let itemsForJSON = posters.map { poster -> PosterItemDTO in
                var imageFilename: String? = poster.imageFilename
                if imageFilename == nil, let uiImage = poster.uiImage {
                    imageFilename = saveImageToDisk(uiImage: uiImage, id: poster.id)
                }
                return PosterItemDTO(
                    id: poster.id,
                    movie: poster.movie,
                    timestamp: poster.timestamp,
                    imageFilename: imageFilename
                )
            }

            let data = try JSONEncoder().encode(itemsForJSON)
            let jsonURL = libraryURL()
            try data.write(to: jsonURL)

        } catch {
            print("Errore nel salvataggio libreria: \(error)")
        }
    }

    // MARK: - Caricamento Libreria da Disco
    func loadLibrary() {
        let jsonURL = libraryURL()
        guard FileManager.default.fileExists(atPath: jsonURL.path) else { return }

        do {
            let data = try Data(contentsOf: jsonURL)
            let decoded = try JSONDecoder().decode([PosterItemDTO].self, from: data)

            let loadedItems: [PosterItem] = decoded.map { dto in
                let possibleImage = loadImageFromDisk(filename: dto.imageFilename)
                return PosterItem(
                    id: dto.id,
                    movie: dto.movie,
                    uiImage: possibleImage,
                    timestamp: dto.timestamp,
                    imageFilename: dto.imageFilename
                )
            }
            self.posters = loadedItems
        } catch {
            print("Errore nel caricamento libreria: \(error)")
            self.posters = []
        }
    }

    // MARK: - Supporto Immagini
    private func saveImageToDisk(uiImage: UIImage, id: UUID) -> String? {
        let folderURL = imagesFolderURL()
        let filename = "\(id.uuidString).png"
        let fileURL = folderURL.appendingPathComponent(filename)
        guard let pngData = uiImage.pngData() else { return nil }
        do {
            try pngData.write(to: fileURL)
            return filename
        } catch {
            print("Errore salvando immagine su disco: \(error)")
            return nil
        }
    }

    private func loadImageFromDisk(filename: String?) -> UIImage? {
        guard let filename = filename else { return nil }
        let fileURL = imagesFolderURL().appendingPathComponent(filename)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            return image
        }
        return nil
    }

    private func deleteImageFromDisk(poster: PosterItem) {
        guard let filename = poster.imageFilename else { return }
        let fileURL = imagesFolderURL().appendingPathComponent(filename)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Errore cancellando immagine: \(error)")
        }
    }

    // MARK: - Path
    private func libraryURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("\(libraryKey).json")
    }

    private func imagesFolderURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(folderName)
    }
}

struct PosterItemDTO: Codable {
    let id: UUID
    let movie: MovieModel
    let timestamp: Date
    let imageFilename: String?
}
