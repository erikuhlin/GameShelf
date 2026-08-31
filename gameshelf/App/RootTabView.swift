//
//  RootTabView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-08.
//

import SwiftUI

struct RootTabView: View {
    enum Tab { case explore, library, search, profile }

    @State private var selection: Tab = .explore

    var body: some View {
        TabView(selection: $selection) {
            ExploreView()
                .tabItem { Label("Utforska", systemImage: "sparkles") }
                .tag(Tab.explore)

            LibraryView()
                .tabItem { Label("Bibliotek", systemImage: "books.vertical.fill") }
                .tag(Tab.library)

            AddGameView(isModal: false)
                .tabItem { Label("Sök", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
        .tint(.ds.brandRed)
    }
}
