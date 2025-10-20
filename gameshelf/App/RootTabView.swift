//
//  RootTabView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-08.
//
import SwiftUI

struct RootTabView: View {
    enum Tab { case explore, library, profile }

    @State private var selection: Tab = .library

    var body: some View {
        TabView(selection: $selection) {
            ExploreView()
                .tabItem { Label("Explore", systemImage: "sparkles") }
                .tag(Tab.explore)

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(Tab.library)

            ProfileView() // ← ny vy
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(Tab.profile)
        }
        .tint(.ds.brandRed) // din accentfärg
    }
}
