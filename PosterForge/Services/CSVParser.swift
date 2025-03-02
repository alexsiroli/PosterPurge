// ========================================
// File: CSVParser.swift
// ========================================
import SwiftUI

class CSVParser {
    static func parseMovies(from csvContent: String) -> [MovieModel] {
        var results: [MovieModel] = []
        
        // [DEBUG] Stampiamo la lunghezza del contenuto e magari le prime 200 battute
        print("[CSVParser] Contenuto CSV length:", csvContent.count)
        let previewStr = csvContent.prefix(200)
        print("[CSVParser] Anteprima CSV:\n\(previewStr)\n---")
        
        // Separiamo in righe
        let lines = csvContent.components(separatedBy: .newlines)
        print("[CSVParser] Numero righe nel CSV:", lines.count)
        
        // Se c'è meno di 2 righe, è probabile che il CSV sia vuoto o malformato
        guard lines.count > 1 else {
            print("[CSVParser] ERRORE: Meno di 2 righe nel CSV; impossibile parse.")
            return []
        }
        
        // Leggiamo l'header (prima riga)
        let headerLine = lines[0]
        let header = headerLine.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        print("[CSVParser] Header rilevato:", header)
        
        // Recuperiamo l'indice delle colonne
        let titleIndex = header.firstIndex(of: "Original Title")
        let yearIndex = header.firstIndex(of: "Year")
        let ratingIndex = header.firstIndex(of: "Your Rating")
        let dateIndex = header.firstIndex(of: "Date Rated")
        let typeIndex = header.firstIndex(of: "Title Type")
        
        // Controlliamo che tutte le colonne ci siano
        if titleIndex == nil || yearIndex == nil || ratingIndex == nil || dateIndex == nil || typeIndex == nil {
            print("[CSVParser] ERRORE: Colonne richieste mancanti!")
            print("[CSVParser] titleIndex:", titleIndex as Any,
                  "yearIndex:", yearIndex as Any,
                  "ratingIndex:", ratingIndex as Any,
                  "dateIndex:", dateIndex as Any,
                  "typeIndex:", typeIndex as Any)
            return []
        }
        
        // Passiamo ogni riga di dati (skip riga 0, che è l'header)
        for (i, rawLine) in lines.enumerated() where i > 0 {
            // Se la riga è vuota o contiene solo virgole, la saltiamo
            if rawLine.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            
            let line = rawLine.split(separator: ",", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            
            // [DEBUG] Puoi decidere di stampare la riga se vuoi, occhio a CSV grandi
            // print("[CSVParser] Riga \(i):", line)
            
            // A volte alcune righe potrebbero avere meno colonne del previsto
            if line.count < header.count {
                print("[CSVParser] Riga \(i) ha meno colonne del previsto (\(line.count)/\(header.count)). Skippata.")
                continue
            }
            
            // Forziamo il unwrap dei vari index (perché abbiamo già controllato)
            let csvTitle = line[titleIndex!]
            let csvYear  = line[yearIndex!]
            let csvRating = line[ratingIndex!]
            let csvDate   = line[dateIndex!]
            let csvType   = line[typeIndex!].lowercased()
            
            let isTV = csvType.contains("tv")
            let ratingInt = Int(csvRating) ?? 0
            
            // Creiamo il MovieModel
            let movie = MovieModel(
                title: csvTitle,
                year: csvYear,
                rating: ratingInt,
                dateWatched: csvDate,
                isTV: isTV
            )
            // [DEBUG]
            print("[CSVParser] Creato MovieModel -> title=\(movie.title), year=\(movie.year), rating=\(movie.rating), isTV=\(movie.isTV)")
            
            results.append(movie)
        }
        
        print("[CSVParser] TOT film trovati nel CSV:", results.count)
        return results
    }
}
