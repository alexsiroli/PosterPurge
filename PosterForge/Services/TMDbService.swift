import Foundation
import os.log
import UIKit

class TMDbService {
    static let shared = TMDbService()

    let apiKey = "8e7466051f04487c6a8248672c859497"
    private let baseURL = "https://api.themoviedb.org/3/"
    private let imageBaseURL = "https://image.tmdb.org/t/p/"
    private let session: URLSession
    private let logger = Logger(subsystem: "com.yourapp.PosterForge", category: "Network")

    private let imageCache = NSCache<NSString, UIImage>()

    init(configuration: URLSessionConfiguration = .default) {
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache.shared
        self.session = URLSession(configuration: configuration)
    }

    struct TMDbSearchResponse: Codable {
        let page: Int
        let results: [TMDbSearchResult]
        let total_pages: Int
        let total_results: Int
    }
    struct TMDbSearchResult: Codable, Identifiable {
        let id: Int
        let media_type: String?
        let title: String?
        let name: String?
        let poster_path: String?
        let backdrop_path: String?
        let release_date: String?
        let first_air_date: String?
        let vote_average: Double?
        let overview: String?

        var displayTitle: String {
            return title ?? name ?? "Unknown Title"
        }
        var releaseYear: String {
            let ds = release_date ?? first_air_date ?? ""
            return String(ds.prefix(4))
        }
    }

    struct TMDbImagesResponse: Codable {
        let posters: [TMDbImageInfo]
        let backdrops: [TMDbImageInfo]
    }
    struct TMDbImageInfo: Codable, Identifiable {
        var id: String { file_path }
        let file_path: String
        let width: Int
        let height: Int
        let iso_639_1: String?
        let aspect_ratio: Double
        let vote_average: Double
        let vote_count: Int

        var url: URL? {
            URL(string: "\(TMDbService.shared.imageBaseURL)original\(file_path)")
        }
    }

    enum MediaType: String {
        case movie, tv
    }
    enum ImageSize: String {
        case small = "w342"
        case medium = "w500"
        case large = "original"
    }
    enum TMDbError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case statusCode(Int)
        case decodingError
        case imageDownloadFailed
        case invalidData
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "URL non valida"
            case .invalidResponse: return "Risposta del server non valida"
            case .statusCode(let c): return "Errore server: \(c)"
            case .decodingError: return "Errore decodifica"
            case .imageDownloadFailed: return "Download immagine fallito"
            case .invalidData: return "Dati non validi"
            }
        }
    }

    // MARK: - Ricerca
    func search(query: String, mediaType: MediaType, year: Int? = nil, page: Int = 1, language: String = "it-IT", completion: @escaping (Result<[TMDbSearchResult], Error>) -> Void) {
        let endpoint = (mediaType == .movie) ? "search/movie" : "search/tv"
        guard var comp = URLComponents(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(TMDbError.invalidURL))
            return
        }
        var qItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        if let y = year {
            if mediaType == .tv {
                qItems.append(URLQueryItem(name: "first_air_date_year", value: "\(y)"))
            } else {
                qItems.append(URLQueryItem(name: "year", value: "\(y)"))
            }
        }
        comp.queryItems = qItems
        guard let url = comp.url else {
            completion(.failure(TMDbError.invalidURL))
            return
        }
        performRequest(url: url) { (res: Result<TMDbSearchResponse, Error>) in
            switch res {
            case .success(let r):
                completion(.success(r.results))
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    // MARK: - Fetch immagini
    func fetchImages(for mediaId: Int, mediaType: MediaType, completion: @escaping (Result<TMDbImagesResponse, Error>) -> Void) {
        let endpoint = "\(mediaType.rawValue)/\(mediaId)/images"
        guard var comp = URLComponents(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(TMDbError.invalidURL))
            return
        }
        // NON filtriamo per lingua: così l'API restituisce tutte le immagini
        comp.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        guard let url = comp.url else {
            completion(.failure(TMDbError.invalidURL))
            return
        }

        performRequest(url: url) { (res: Result<TMDbImagesResponse, Error>) in
            switch res {
            case .success(let raw):
                // Ordinamento: immagini senza lingua (o "null") -> "it" -> "en" -> tutte le altre
                let reordered = raw.posters.sorted { p1, p2 in
                    func rank(for lang: String?) -> Int {
                        // Se non c'è valore o se è "null", assegna il rango più basso (0)
                        guard let l = lang, l != "null" else { return 0 }
                        if l == "it" { return 1 }
                        if l == "en" { return 2 }
                        return 3
                    }
                    let rank1 = rank(for: p1.iso_639_1)
                    let rank2 = rank(for: p2.iso_639_1)
                    if rank1 == rank2 {
                        return false // manteniamo l'ordine originale se hanno stesso rango
                    }
                    return rank1 < rank2
                }
                let out = TMDbImagesResponse(posters: reordered, backdrops: raw.backdrops)
                completion(.success(out))
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }

    // MARK: - Download immagine
    func downloadImage(path: String, size: ImageSize = .large, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let urlString = "\(imageBaseURL)\(size.rawValue)\(path)"
        guard let url = URL(string: urlString) else {
            completion(.failure(TMDbError.invalidURL))
            return
        }
        if let c = imageCache.object(forKey: url.absoluteString as NSString) {
            completion(.success(c))
            return
        }
        session.dataTask(with: url) { data, _, err in
            if let e = err {
                completion(.failure(e))
                return
            }
            guard let d = data, let img = UIImage(data: d) else {
                completion(.failure(TMDbError.imageDownloadFailed))
                return
            }
            self.imageCache.setObject(img, forKey: url.absoluteString as NSString)
            completion(.success(img))
        }.resume()
    }

    // MARK: - Async
    @available(iOS 13.0, *)
    func search(query: String, mediaType: MediaType, year: Int? = nil, page: Int = 1, language: String = "it-IT") async throws -> [TMDbSearchResult] {
        try await withCheckedThrowingContinuation { c in
            self.search(query: query, mediaType: mediaType, year: year, page: page, language: language) { res in
                c.resume(with: res)
            }
        }
    }
    @available(iOS 13.0, *)
    func fetchImages(for mediaId: Int, mediaType: MediaType) async throws -> TMDbImagesResponse {
        try await withCheckedThrowingContinuation { c in
            self.fetchImages(for: mediaId, mediaType: mediaType) { res in
                c.resume(with: res)
            }
        }
    }
    @available(iOS 13.0, *)
    func downloadImage(path: String, size: ImageSize = .large) async throws -> UIImage? {
        try await withCheckedThrowingContinuation { cc in
            self.downloadImage(path: path, size: size) { r in
                cc.resume(with: r)
            }
        }
    }

    // MARK: - Generic
    private func performRequest<T: Decodable>(url: URL, completion: @escaping (Result<T, Error>) -> Void) {
        session.dataTask(with: url) { data, resp, err in
            if let e = err {
                DispatchQueue.main.async {
                    completion(.failure(e))
                }
                return
            }
            guard let http = resp as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(TMDbError.invalidResponse))
                }
                return
            }
            guard (200...299).contains(http.statusCode) else {
                DispatchQueue.main.async {
                    completion(.failure(TMDbError.statusCode(http.statusCode)))
                }
                return
            }
            guard let d = data else {
                DispatchQueue.main.async {
                    completion(.failure(TMDbError.invalidData))
                }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: d)
                DispatchQueue.main.async {
                    completion(.success(decoded))
                }
            } catch {
                self.logger.error("Decoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(TMDbError.decodingError))
                }
            }
        }.resume()
    }
}
