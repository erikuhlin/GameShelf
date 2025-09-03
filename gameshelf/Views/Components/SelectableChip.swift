//
//  SelectableChip.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-26.
//


import SwiftUI

struct SelectableChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
