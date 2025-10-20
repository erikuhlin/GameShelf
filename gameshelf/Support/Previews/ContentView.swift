import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.ds.background.ignoresSafeArea()   // Edge-to-edge app background
            NavigationStack {
                LibraryView()                        // startvy
                    .navigationTitle("Gameshelf")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview {
    // Preview with an in-memory sample store
    ContentView()
        .environmentObject(LibraryStore())
}
