//
//  TrendingSection.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//

import SwiftUI

struct TrendingSection: View {
    let items: [TrendingItem]
    var isLoading: Bool = false
    var showHeader: Bool = true
    var onSelect: (Int) -> Void = { _ in }
    var onSeeAll: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showHeader {
                HStack {
                    Text("Trendar just nu")
                        .font(.headline.bold())
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !items.isEmpty {
                        Button(action: onSeeAll) {
                            Text("Visa alla ›")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.brandRed)
                        }
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
                    Text("Inga trendande titlar just nu.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items.prefix(12)) { g in
                            Button { onSelect(g.id) } label: {
                                GameCard(
                                    trendingItem: g,
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
