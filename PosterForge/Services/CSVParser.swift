// ========================================
// File: CSVParser.swift
// ========================================
import SwiftUI

class CSVParser {
    /// Estrae i film dal CSV. Niente stampe di debug, solo eventuali errori basilari.
    static func parseMovies(from csvContent: String) -> [MovieModel] {
        var results: [MovieModel] = []

        // Separiamo in righe
        let lines = csvContent.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            print("ERRORE CSVParser: Meno di 2 righe nel CSV; impossibile parse.")
            return []
        }

        // Header
        let headerLine = lines[0]
        let header = headerLine.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

        let titleIndex = header.firstIndex(of: "Original Title")
        let yearIndex = header.firstIndex(of: "Year")
        let ratingIndex = header.firstIndex(of: "Your Rating")
        let dateIndex = header.firstIndex(of: "Date Rated")
        let typeIndex = header.firstIndex(of: "Title Type")

        // Se mancano le colonne richieste, ritorniamo vuoto
        if titleIndex == nil || yearIndex == nil || ratingIndex == nil || dateIndex == nil || typeIndex == nil {
            print("ERRORE CSVParser: Colonne richieste mancanti (Original Title, Year, Your Rating, Date Rated, Title Type).")
            return []
        }

        // Parsing righe
        for i in 1..<lines.count {
            let rawLine = lines[i].trimmingCharacters(in: .whitespaces)
            if rawLine.isEmpty { continue } // saltiamo righe vuote

            let line = rawLine.split(separator: ",", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespaces) }

            // Se la riga ha meno colonne del previsto, la saltiamo
            if line.count < header.count { continue }

            // Decodifica
            let csvTitle = line[titleIndex!]
            let csvYear  = line[yearIndex!]
            let csvRating = line[ratingIndex!]
            let csvDate   = line[dateIndex!]
            let csvType   = line[typeIndex!].lowercased()

            let isTV = csvType.contains("tv")
            let ratingInt = Int(csvRating) ?? 0

            let movie = MovieModel(
                title: csvTitle,
                year: csvYear,
                rating: ratingInt,
                dateWatched: csvDate,
                isTV: isTV
            )
            results.append(movie)
        }

        return results
    }
}
