import SwiftUI

struct PosterItem: Identifiable, Equatable {
    let id: UUID
    let movie: MovieModel
    var uiImage: UIImage?
    let timestamp: Date
    let imageFilename: String?

    var image: Image {
        guard let uiImage = uiImage else {
            return Image(systemName: "photo")
        }
        return Image(uiImage: uiImage)
    }
}
