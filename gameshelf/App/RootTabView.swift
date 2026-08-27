//
//  RootTabView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-08.
//

import SwiftUI

struct RootTabView: View {
    enum Tab { case explore, library, activity }

    @State private var selection: Tab = .library

    var body: some View {
        TabView(selection: $selection) {
            ExploreView()
                .tabItem { Label("Utforska", systemImage: "sparkles") }
                .tag(Tab.explore)

            LibraryView()
                .tabItem { Label("Bibliotek", systemImage: "books.vertical.fill") }
                .tag(Tab.library)

            ActivityView()
                .tabItem { Label("Aktivitet", systemImage: "chart.bar.xaxis") }
                .tag(Tab.activity)
        }
        .tint(.ds.brandRed)
    }
}
