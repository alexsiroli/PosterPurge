// ========================================
// File: MovieModel.swift
// ========================================
import SwiftUI

/// Modello per rappresentare un film/serie come appare nel CSV
struct MovieModel: Identifiable, Equatable, Codable {
    let id = UUID()

    var title: String
    var year: String
    var rating: Int
    var dateWatched: String
    var isTV: Bool

    var normalizedTitle: String {
        return title
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .lowercased()
    }
}
