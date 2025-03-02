// ========================================
// File: TMDbService.swift
// ========================================
import Foundation
import os.log
import UIKit

class TMDbService {
    static let shared = TMDbService()
    
    private let apiKey = "8e7466051f04487c6a8248672c859497"
    private let baseURL = "https://api.themoviedb.org/3/"
    private let imageBaseURL = "https://image.tmdb.org/t/p/"
    private let session: URLSession
    private let logger = Logger(subsystem: "com.yourapp.PosterForge", category: "Network")
    
    // Cache per le immagini
    private let imageCache = NSCache<NSString, UIImage>()
    
    init(configuration: URLSessionConfiguration = .default) {
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache.shared
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Modelli dati
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
            let dateString = release_date ?? first_air_date ?? ""
            return String(dateString.prefix(4))
        }
    }
    
    struct TMDbImagesResponse: Codable {
        let posters: [TMDbImageInfo]
        let backdrops: [TMDbImageInfo]
    }
    
    struct TMDbImageInfo: Codable, Identifiable {
        // Creiamo un id fittizio per conformità a Identifiable
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
        case movie
        case tv
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
            case .statusCode(let code): return "Errore server: \(code)"
            case .decodingError: return "Errore nell'elaborazione dei dati"
            case .imageDownloadFailed: return "Download immagine fallito"
            case .invalidData: return "Dati ricevuti non validi"
            }
        }
    }
    
    // MARK: - Funzioni di ricerca (callback)
    func search(
        query: String,
        mediaType: MediaType,
        year: Int? = nil,
        page: Int = 1,
        language: String = "it-IT",
        completion: @escaping (Result<[TMDbSearchResult], Error>) -> Void
    ) {
        let endpoint: String
        switch mediaType {
        case .movie:
            endpoint = "search/movie"
        case .tv:
            endpoint = "search/tv"
        }
        
        var components = URLComponents(string: "\(baseURL)\(endpoint)")!
        var queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        
        if let year = year {
            queryItems.append(
                URLQueryItem(
                    name: mediaType == .movie ? "year" : "first_air_date_year",
                    value: "\(year)"
                )
            )
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            completion(.failure(TMDbError.invalidURL))
            return
        }
        
        performRequest(url: url) { (result: Result<TMDbSearchResponse, Error>) in
            switch result {
            case .success(let response):
                completion(.success(response.results))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch dettagli immagini (callback)
    func fetchImages(
        for mediaId: Int,
        mediaType: MediaType,
        language: String? = nil,
        completion: @escaping (Result<TMDbImagesResponse, Error>) -> Void
    ) {
        let endpoint = "\(mediaType.rawValue)/\(mediaId)/images"
        var components = URLComponents(string: "\(baseURL)\(endpoint)")!
        
        // Lingue
        var qItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            // forziamo "null" come prima preferenza, poi it, poi en
            URLQueryItem(name: "include_image_language", value: "null,it,en")
        ]
        
        if let language = language {
            qItems.append(URLQueryItem(name: "language", value: language))
        }
        
        components.queryItems = qItems
        
        guard let url = components.url else {
            completion(.failure(TMDbError.invalidURL))
            return
        }
        
        performRequest(url: url, completion: completion)
    }
    
    // MARK: - Download immagini (callback)
    func downloadImage(
        path: String,
        size: ImageSize = .large,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        let urlString = "\(imageBaseURL)\(size.rawValue)\(path)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(TMDbError.invalidURL))
            return
        }
        
        // Cache
        if let cachedImage = imageCache.object(forKey: url.absoluteString as NSString) {
            completion(.success(cachedImage))
            return
        }
        
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(TMDbError.imageDownloadFailed))
                return
            }
            
            self.imageCache.setObject(image, forKey: url.absoluteString as NSString)
            completion(.success(image))
        }.resume()
    }
    
    // MARK: - Funzioni Async/Await
    @available(iOS 13.0, *)
    func search(
        query: String,
        mediaType: MediaType,
        year: Int? = nil,
        page: Int = 1,
        language: String = "it-IT"
    ) async throws -> [TMDbSearchResult] {
        try await withCheckedThrowingContinuation { continuation in
            search(query: query, mediaType: mediaType, year: year, page: page, language: language) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    @available(iOS 13.0, *)
    func fetchImages(
        for mediaId: Int,
        mediaType: MediaType,
        language: String? = nil
    ) async throws -> TMDbImagesResponse {
        try await withCheckedThrowingContinuation { continuation in
            fetchImages(for: mediaId, mediaType: mediaType, language: language) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    @available(iOS 13.0, *)
    func downloadImage(path: String, size: ImageSize = .large) async throws -> UIImage? {
        try await withCheckedThrowingContinuation { continuation in
            downloadImage(path: path, size: size) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // MARK: - Funzione generica per le richieste
    private func performRequest<T: Decodable>(
        url: URL,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(TMDbError.invalidResponse))
                }
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    completion(.failure(TMDbError.statusCode(httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(TMDbError.invalidData))
                }
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
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
