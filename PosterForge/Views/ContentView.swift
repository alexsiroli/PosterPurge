import SwiftUI

struct ContentView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @StateObject var libraryVM = LibraryViewModel()
    
    @State private var activeSheet: ActiveSheet?
    
    enum ActiveSheet: Identifiable {
        case settings, csvImport, search, library
        var id:Int{hashValue}
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors:[
                    Color(red:0.1,green:0.1,blue:0.1),
                    Color(red:0.2,green:0.2,blue:0.2)]),
                    startPoint:.top, endPoint:.bottom
                )
                .edgesIgnoringSafeArea(.all)

                VStack(spacing:40){
                    Spacer()
                    VStack(spacing:12){
                        Text("PosterForge")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                        Text("Crea e gestisci i tuoi poster personalizzati")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing:20){
                        actionButton("Carica CSV", icon:"tray.and.arrow.down", sheet:.csvImport)
                        actionButton("Cerca Film/Serie", icon:"magnifyingglass", sheet:.search)
                        actionButton("Mostra Libreria", icon:"photo.stack", sheet:.library)
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationBarItems(trailing: Button {
                activeSheet = .settings
            } label:{
                Image(systemName:"gearshape").foregroundColor(.white)
            })
            .sheet(item: $activeSheet){sheet in
                switch sheet {
                case .settings:
                    SettingsView()
                case .csvImport:
                    CSVImportView(libraryVM: libraryVM)
                case .search:
                    SearchView(libraryVM: libraryVM)
                case .library:
                    LibraryView(libraryVM: libraryVM)
                }
            }
        }
    }

    @ViewBuilder
    private func actionButton(_ title:String, icon:String, sheet:ActiveSheet)-> some View {
        Button {
            activeSheet=sheet
        } label:{
            HStack{
                Image(systemName:icon)
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
