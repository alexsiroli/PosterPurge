import SwiftUI

class CSVParser {
    static func parseMovies(from csvContent:String)->[MovieModel] {
        var results:[MovieModel]=[]
        let lines=csvContent.components(separatedBy:.newlines)
        guard lines.count>1 else {
            print("ERRORE CSVParser: Meno di 2 righe nel CSV; impossibile parse.")
            return[]
        }
        let headerLine=lines[0]
        let header=headerLine.split(separator:",").map{ String($0).trimmingCharacters(in:.whitespaces)}

        let tIndex = header.firstIndex(of:"Original Title")
        let yIndex = header.firstIndex(of:"Year")
        let rIndex = header.firstIndex(of:"Your Rating")
        let dIndex = header.firstIndex(of:"Date Rated")
        let typeIndex = header.firstIndex(of:"Title Type")
        if tIndex==nil || yIndex==nil || rIndex==nil || dIndex==nil || typeIndex==nil {
            print("ERRORE CSVParser: Colonne richieste mancanti (Original Title, Year, Your Rating, Date Rated, Title Type).")
            return[]
        }
        for i in 1..<lines.count {
            let rawLine=lines[i].trimmingCharacters(in:.whitespaces)
            if rawLine.isEmpty {continue}
            let line=rawLine.split(separator:",", omittingEmptySubsequences:false)
                .map{String($0).trimmingCharacters(in:.whitespaces)}
            if line.count<header.count {continue}

            let csvTitle=line[tIndex!]
            let csvYear=line[yIndex!]
            let csvRating=line[rIndex!]
            let csvDate=line[dIndex!]
            let csvType=line[typeIndex!].lowercased()

            let isTV=csvType.contains("tv")
            let ratingInt=Int(csvRating) ?? 0
            let mov=MovieModel(
                title:csvTitle,
                year:csvYear,
                rating:ratingInt,
                dateWatched:csvDate,
                isTV:isTV
            )
            results.append(mov)
        }
        return results
    }
}
