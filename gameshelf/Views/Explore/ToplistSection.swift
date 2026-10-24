//
//  ToplistSection.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-10-02.
//

import SwiftUI

struct ToplistSection: View {
    var showHeader: Bool = true
    var onSelect: (Int) -> Void = { _ in }
    var onSeeAll: () -> Void = {}

    @State private var items: [ToplistGameItem] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showHeader {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(Color.feedbackWarning)
                        Text("Topp 100 Spel")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Visa alla 100 ›", action: onSeeAll)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.brandRed)
                    }
                }
            }

            if isLoading && items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            skeletonCard
                        }
                    }
                }
            } else if items.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "trophy")
                            .font(.title2)
                            .foregroundStyle(Color.textSecondary)
                        Text("Inga titlar i topplistan än.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(items.prefix(15).enumerated()), id: \.element.id) { index, game in
                            Button {
                                onSelect(game.id)
                            } label: {
                                GameCard(
                                    toplistItem: game,
                                    rank: index + 1,
                                    width: 136,
                                    coverHeight: 176
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 2)
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

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(hex: "#2C2C2E"))
                .frame(width: 136, height: 176)
                .overlay(ProgressView().tint(Color.brandRed))

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 60, height: 12)
            }
            .padding(10)
            .frame(width: 136, height: 92, alignment: .topLeading)
        }
        .frame(width: 136, height: 268)
        .background(Color.neutralSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
