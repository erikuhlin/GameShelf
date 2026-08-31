//
//  TrendingListView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//


import SwiftUI

struct TrendingListView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [TrendingItem]
    var onRefresh: (() async -> Void)? = nil
    var onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "flame")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Inga trendande titlar hittades")
                            .font(.headline)
                        Text("Dra nedåt för att uppdatera.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
                                        if let badge = g.badgeText {
                                            Text(badge)
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.red.opacity(0.12))
                                                .foregroundStyle(.red)
                                                .clipShape(Capsule())
                                        }
                                        Text(g.platformText).lineLimit(1)
                                        if g.rating > 0 {
                                            Text("· \(String(format: "%.1f", g.rating))/10")
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
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Trendar just nu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
            .refreshable {
                if let onRefresh = onRefresh {
                    await onRefresh()
                }
            }
        }
    }
}
