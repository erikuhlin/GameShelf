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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.ds.brandRed)
                .background(Color.ds.background)
                .environmentObject(store)
        }
    }
}
