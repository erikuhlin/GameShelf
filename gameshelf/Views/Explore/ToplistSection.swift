//
//  ToplistSection.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-10-02.
//

import SwiftUI

struct ToplistSection: View {
    var onSelect: (Int) -> Void = { _ in }
    var onSeeAll: () -> Void = {}

    @State private var items: [ToplistGameItem] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("Topp 100 Spel")
                        .font(.title3.bold())
                }
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Visa alla 100", action: onSeeAll)
                        .font(.callout.bold())
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal)

            if isLoading && items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            skeletonCard
                        }
                    }
                    .padding(.horizontal)
                }
            } else if items.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "trophy")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Inga titlar i topplistan än.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(items.prefix(15).enumerated()), id: \.element.id) { index, game in
                            Button {
                                onSelect(game.id)
                            } label: {
                                topCard(game: game, rank: index + 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            if items.isEmpty {
                do {
                    items = try await ToplistService.shared.fetchToplist(limit: 15)
                } catch {
                    print("Could not load preview toplist: \(error)")
                }
                isLoading = false
            }
        }
    }

    private func topCard(game: ToplistGameItem, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Omslag
                AsyncImage(url: game.coverURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .overlay {
                                Image(systemName: "gamecontroller")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 140, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)

                // Rank Badge
                HStack(spacing: 2) {
                    if rank == 1 {
                        Text("🥇 #1")
                    } else if rank == 2 {
                        Text("🥈 #2")
                    } else if rank == 3 {
                        Text("🥉 #3")
                    } else {
                        Text("#\(rank)")
                    }
                }
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .background(rank <= 3 ? Color.yellow.opacity(0.25) : Color.black.opacity(0.4))
                .clipShape(Capsule())
                .padding(8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)

                HStack(spacing: 4) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        Text(game.formattedScore)
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                    }

                    if let year = game.release_year {
                        Text("· \(String(year))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(width: 140)
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 140, height: 180)
                .overlay(ProgressView().scaleEffect(0.7))

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.quaternarySystemFill))
                .frame(width: 110, height: 14)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.quaternarySystemFill))
                .frame(width: 70, height: 12)
        }
    }
}
