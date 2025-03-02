// ========================================
// File: TMDbService.swift
// ========================================
import SwiftUI

class TMDbService {
    static let shared = TMDbService()

    // Sostituisci con la tua vera API Key
    private let apiKey = "8e7466051f04487c6a8248672c859497"

    private let session = URLSession.shared

    /// Ricerca un film (o serie TV) su TMDb
    func search(query: String, isTV: Bool, year: Int? = nil, completion: @escaping ([TMDbSearchResult]) -> Void) {
        let baseURL = "https://api.themoviedb.org/3/search/"
        let endpoint = isTV ? "tv" : "movie"

        var urlString = "\(baseURL)\(endpoint)?api_key=\(apiKey)&query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let y = year {
            if isTV {
                urlString += "&first_air_date_year=\(y)"
            } else {
                urlString += "&year=\(y)"
            }
        }
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion([])
            }
            return
        }

        session.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(TMDbSearchResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(decoded.results)
                }
            } catch {
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }.resume()
    }

    /// Ottiene la lista di poster di un film/serie
    func fetchPosters(itemID: Int, isTV: Bool, languagePref: String? = nil, completion: @escaping ([TMDbImageInfo]) -> Void) {
        let baseURL = "https://api.themoviedb.org/3/"
        let endpoint = isTV ? "tv" : "movie"

        var includeLangParam = ""
        if let lp = languagePref {
            switch lp {
            case "none":
                includeLangParam = "&include_image_language=null,it,en"
            case "it":
                includeLangParam = "&include_image_language=it,null,en"
            case "en":
                includeLangParam = "&include_image_language=en,null,it"
            default:
                break
            }
        }

        let urlString = "\(baseURL)\(endpoint)/\(itemID)/images?api_key=\(apiKey)\(includeLangParam)"

        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion([])
            }
            return
        }

        session.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(TMDbImagesResponse.self, from: data)
                let posters = decoded.posters
                DispatchQueue.main.async {
                    completion(posters)
                }
            } catch {
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }.resume()
    }

    /// Scarica un'immagine da TMDb
    func downloadPoster(path: String, completion: @escaping (UIImage?) -> Void) {
        let urlString = "https://image.tmdb.org/t/p/original\(path)"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        session.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil, let img = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            DispatchQueue.main.async {
                completion(img)
            }
        }.resume()
    }
}

// MARK: - TMDb Response Models
struct TMDbSearchResponse: Codable {
    let results: [TMDbSearchResult]
}

struct TMDbSearchResult: Codable {
    let id: Int
    let name: String?       // per le serie
    let title: String?      // per i film
    let first_air_date: String?
    let release_date: String?
}

struct TMDbImagesResponse: Codable {
    let posters: [TMDbImageInfo]
}

struct TMDbImageInfo: Codable {
    let file_path: String
    let width: Int
    let height: Int
}
