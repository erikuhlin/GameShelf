//
//  TrendingListView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//


import SwiftUI

struct TrendingListView: View {
    let items: [TrendingItem]
    var onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            List(items) { g in
                Button { onSelect(g.id) } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                            if let url = g.image {
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
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(g.title).font(.headline).lineLimit(2)
                            HStack(spacing: 6) {
                                Text(g.platformText).lineLimit(1)
                                if g.rating > 0 {
                                    Text("· \(String(format: "%.1f", g.rating))/5")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Trending")
        }
    }
}