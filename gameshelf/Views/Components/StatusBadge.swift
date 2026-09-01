//
//  StatusBadge.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI

struct StatusBadge: View {
    let status: PlayStatus
    var isMultiplayerOrOngoing: Bool = false
    var isBacklog: Bool = false

    init(status: PlayStatus, isMultiplayerOrOngoing: Bool = false, isBacklog: Bool = false) {
        self.status = status
        self.isMultiplayerOrOngoing = isMultiplayerOrOngoing
        self.isBacklog = isBacklog
    }

    init(game: Game) {
        self.status = game.status
        self.isMultiplayerOrOngoing = game.isMultiplayerOrOngoing
        self.isBacklog = game.isBacklog
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isBacklog && status == .notStarted ? "archivebox.fill" : status.icon(isMultiplayerOrOngoing: isMultiplayerOrOngoing))
                .font(.system(size: 9, weight: .bold))
            Text(isBacklog && status == .notStarted ? "Backlog" : status.title(isMultiplayerOrOngoing: isMultiplayerOrOngoing))
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(Color.white)
        .background(isBacklog && status == .notStarted ? Color.blue : status.color, in: Capsule())
    }
}