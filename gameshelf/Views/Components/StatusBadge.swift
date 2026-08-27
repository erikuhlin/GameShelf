//
//  StatusBadge.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI

struct StatusBadge: View {
    let status: PlayStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 9, weight: .bold))
            Text(status.rawValue)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(Color.white)
        .background(status.color, in: Capsule())
    }
}