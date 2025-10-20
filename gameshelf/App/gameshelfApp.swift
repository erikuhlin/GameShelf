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
    @StateObject private var profile = ProfileStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(.ds.brandRed)
                .background(Color.ds.background)
                .environmentObject(store)
                .environmentObject(profile)
        }
    }
}
