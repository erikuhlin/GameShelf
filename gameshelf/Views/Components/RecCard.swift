//
//  RecCard.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//


import SwiftUI

struct RecCard: View {
    let title: String
    let subtitle: String
    let rating: Double
    let imageURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary)
                if let url = imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Color.clear
                        }
                    }
                } else {
                    Image(systemName: "gamecontroller").imageScale(.large)
                }
            }
            .frame(width: 160, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(minHeight: 48, alignment: .topLeading)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 2) {
                    ForEach(0..<5) { i in
                        if rating >= Double(i + 1) {
                            Image(systemName: "star.fill")
                        } else if rating > Double(i) && rating < Double(i + 1) {
                            Image(systemName: "star.leadinghalf.filled")
                        } else {
                            Image(systemName: "star")
                        }
                    }
                }
                .font(.caption)
                .opacity(rating > 0 ? 1 : 0)
                .accessibilityHidden(rating <= 0)
            }
        }
        .frame(width: 160)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.ds.surface))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}
