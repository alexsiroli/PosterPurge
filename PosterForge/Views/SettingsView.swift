// ========================================
// File: SettingsView.swift
// ========================================
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Environment(\.presentationMode) var presentationMode

    @State private var showingResetAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Lingua preferita poster")) {
                    Picker("Lingua", selection: $preferencesManager.preferences.preferredLanguage) {
                        Text("No language").tag("none")
                        Text("Italiano").tag("it")
                        Text("Inglese").tag("en")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Modalità selezione locandine")) {
                    // "automatica" vs "manuale"
                    Picker("Scelta locandine", selection: $preferencesManager.preferences.posterSelectionMode) {
                        Text("Automatica").tag("automatic")
                        Text("Manuale").tag("manual")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section {
                    Button("Reset libreria") {
                        showingResetAlert = true
                    }
                    .alert(isPresented: $showingResetAlert) {
                        Alert(
                            title: Text("Conferma cancellazione"),
                            message: Text("Vuoi davvero cancellare tutte le copertine della libreria? L'operazione è irreversibile."),
                            primaryButton: .destructive(Text("Sì, cancella")) {
                                resetLibrary()
                            },
                            secondaryButton: .cancel(Text("Annulla"))
                        )
                    }
                }

                Section {
                    Button("Salva e chiudi") {
                        preferencesManager.savePreferences()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Impostazioni")
        }
    }

    private func resetLibrary() {
        // Azzeriamo i poster
        preferencesManager.savePreferences()

        // Serve un meccanismo per avvisare la LibraryViewModel. Possiamo usare NotificationCenter
        // o passare l'oggetto come environmentObject. Qui optiamo per una notifica semplificata:
        NotificationCenter.default.post(name: .libraryResetRequested, object: nil)
    }
}

// Aggiungiamo un "NSNotification.Name" per segnalare la richiesta di reset libreria
extension Notification.Name {
    static let libraryResetRequested = Notification.Name("libraryResetRequested")
}
