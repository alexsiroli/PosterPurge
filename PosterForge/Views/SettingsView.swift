import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Environment(\.presentationMode) var presentationMode

    @State private var showingResetAlert=false

    var body: some View {
        NavigationView {
            Form {
                Section(header:Text("Modalità selezione locandine")) {
                    Picker("Scelta locandine", selection:$preferencesManager.preferences.posterSelectionMode) {
                        Text("Automatica").tag("automatic")
                        Text("Manuale").tag("manual")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section {
                    Button("Reset libreria"){
                        showingResetAlert=true
                    }
                    .alert(isPresented:$showingResetAlert){
                        Alert(
                            title:Text("Conferma cancellazione"),
                            message:Text("Vuoi davvero cancellare tutte le copertine della libreria? L'operazione è irreversibile."),
                            primaryButton:.destructive(Text("Sì, cancella")){
                                resetLibrary()
                            },
                            secondaryButton:.cancel(Text("Annulla"))
                        )
                    }
                }
                Section {
                    Button("Salva e chiudi"){
                        preferencesManager.savePreferences()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Impostazioni")
        }
    }

    private func resetLibrary() {
        preferencesManager.savePreferences()
        NotificationCenter.default.post(name: .libraryResetRequested, object:nil)
    }
}

extension Notification.Name {
    static let libraryResetRequested=Notification.Name("libraryResetRequested")
}
