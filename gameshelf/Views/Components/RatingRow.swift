//
//  RatingRow.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//


import SwiftUI

struct RatingRow: View {
    @Binding var rating: Int?
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...10, id: \.self) { i in
                Image(systemName: (rating ?? 0) >= i ? "star.fill" : "star")
                    .onTapGesture { rating = i }
            }
        }
        .font(.caption)
        .foregroundStyle(.yellow)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating ?? 0) of 10")
    }
}