import SwiftUI

struct ContentView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @StateObject var libraryVM = LibraryViewModel()

    @State private var showSettings = false
    @State private var showCSVImport = false
    @State private var showSearch = false
    @State private var showLibrary = false

    var body: some View {
        NavigationView {
            ZStack {
                // Sfondo più "moderno": un gradiente violaceo (a esempio)
                LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]),
                               startPoint: .top,
                               endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 30) {
                    Text("PosterForge")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)

                    Text("Crea e gestisci i tuoi poster personalizzati")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 40)

                    buttonStyle("1) Carica CSV", icon: "tray.and.arrow.down") {
                        showCSVImport = true
                    }

                    buttonStyle("2) Cerca un Film / Serie", icon: "magnifyingglass") {
                        showSearch = true
                    }

                    buttonStyle("3) Mostra Libreria", icon: "photo.tv") {
                        showLibrary = true
                    }

                    Spacer()
                }
                .padding()
                .navigationBarItems(trailing:
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                )
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                        .environmentObject(preferencesManager)
                }
                .sheet(isPresented: $showCSVImport) {
                    CSVImportView(libraryVM: libraryVM)
                        .environmentObject(preferencesManager)
                }
                .sheet(isPresented: $showSearch) {
                    SearchView(libraryVM: libraryVM)
                        .environmentObject(preferencesManager)
                }
                .sheet(isPresented: $showLibrary) {
                    LibraryView(libraryVM: libraryVM)
                }
            }
            .onAppear {
                // ...
            }
        }
    }

    @ViewBuilder
    private func buttonStyle(_ title: String, icon: String, action: @escaping ()->Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.title3)
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
        }
    }
}
