import SwiftUI

struct ContentView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @StateObject var libraryVM = LibraryViewModel()
    
    @State private var activeSheet: ActiveSheet?
    @State private var showLoading = false
    
    enum ActiveSheet: Identifiable {
        case settings, csvImport, search, library
        var id: Int { hashValue }
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]),
                               startPoint: .top,
                               endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    // Header Section
                    VStack(spacing: 12) {
                        Text("PosterForge")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                        
                        Text("Crea e gestisci i tuoi poster personalizzati")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Action Buttons
                    VStack(spacing: 20) {
                        actionButton("Carica CSV", icon: "tray.and.arrow.down", sheet: .csvImport)
                        actionButton("Cerca Film/Serie", icon: "magnifyingglass", sheet: .search)
                        actionButton("Mostra Libreria", icon: "photo.stack", sheet: .library)
                    }
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarItems(trailing: settingsButton)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .settings: SettingsView()
                case .csvImport: CSVImportView(libraryVM: libraryVM)
                case .search: SearchView(libraryVM: libraryVM)
                case .library: LibraryView(libraryVM: libraryVM)
                }
            }
        }
    }
    
    private var settingsButton: some View {
        Button(action: { activeSheet = .settings }) {
            Image(systemName: "gearshape")
                .foregroundColor(.white)
        }
    }
    
    private func actionButton(_ title: String, icon: String, sheet: ActiveSheet) -> some View {
        Button(action: { activeSheet = sheet }) {
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
