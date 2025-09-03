//
//  PlayStatus.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//


import SwiftUI

enum PlayStatus: String, CaseIterable, Codable, Identifiable {
    case playing = "Playing"
    case completed = "Completed"
    case abandoned = "Abandoned"
    case wishlist = "Wishlist"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .playing: return .blue
        case .completed: return .green
        case .abandoned: return .red
        case .wishlist: return .gray
        }
    }
}