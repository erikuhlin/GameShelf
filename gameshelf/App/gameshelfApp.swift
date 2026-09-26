//
//  gameshelfApp.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//


import SwiftUI

@main



struct gameshelfApp: App {
    @StateObject private var store = LibraryStore()
    @StateObject private var profile = ProfileStore.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
                .tint(.ds.brandRed)
                .background(Color.ds.background)
                .environmentObject(store)
                .environmentObject(profile)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "gameshelf" else { return }

        // Om det är en parkopplingslänk från webben: gameshelf://pair?code=GS-XXXX
        if url.host == "pair" || url.path.contains("pair"),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            let currentGames = store.games
            let currentCollections = store.collections
            let currentUsername = profile.username

            Task {
                try? await SupabaseSyncService.shared.upsertGames(currentGames)
                for col in currentCollections {
                    try? await SupabaseSyncService.shared.upsertCollection(col)
                }
                try? await SupabasePairingService.shared.approvePairing(code: code, username: currentUsername)
                await MainActor.run {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
        }
    }
}
