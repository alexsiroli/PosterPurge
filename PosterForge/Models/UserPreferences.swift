import SwiftUI

struct UserPreferences: Codable {
    var preferredLanguage: String
    var posterSelectionMode: String  // "automatic" o "manual"

    init(preferredLanguage: String = "none",
         posterSelectionMode: String = "automatic") {
        self.preferredLanguage = preferredLanguage
        self.posterSelectionMode = posterSelectionMode
    }
}

class PreferencesManager: ObservableObject {
    @Published var preferences: UserPreferences = UserPreferences()
    private let preferencesKey = "PosterForgeUserPreferences"

    init() {
        loadPreferences()
    }

    func loadPreferences() {
        guard let data = UserDefaults.standard.data(forKey: preferencesKey) else { return }
        if let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            self.preferences = decoded
        }
    }

    func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: preferencesKey)
        }
    }

    func resetPreferences() {
        preferences = UserPreferences()
        savePreferences()
    }
}
