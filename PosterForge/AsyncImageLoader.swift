struct AsyncImageLoader: View {
    let url: URL?
    let placeholder: Image
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
            }
        }
        .onAppear(perform: loadImage)
        .onChange(of: url) { _ in loadImage() }
    }
    
    private func loadImage() {
        guard let url = url, image == nil else { return }
        
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    return
                }
                
                if let data = data, let image = UIImage(data: data) {
                    self.image = image
                }
            }
        }.resume()
    }
}
