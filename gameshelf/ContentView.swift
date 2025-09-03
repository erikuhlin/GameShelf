import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            LibraryView()                              // din startvy
                .navigationTitle("Gameshelf")
        }
        .padding(Spacing.l)
        .background(Color.ds.background.ignoresSafeArea())
    }
}

#Preview {
    // Preview with an in-memory sample store
    ContentView()
        .environmentObject(LibraryStore())
}
