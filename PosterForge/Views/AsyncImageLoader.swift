import SwiftUI
import UIKit

struct AsyncImageLoader: View {
    let url: URL?
    let placeholder: Image
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image).resizable()
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
            }
        }
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        guard let url = url else { return }
        isLoading = true
        URLSession.shared.dataTask(with: url) { data,_,err in
            DispatchQueue.main.async {
                self.isLoading = false
                if let e = err { self.error=e;return}
                if let data=data, let img=UIImage(data:data){
                    self.image=img
                }
            }
        }.resume()
    }
}
