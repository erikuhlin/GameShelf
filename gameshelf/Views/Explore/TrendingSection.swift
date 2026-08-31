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
    var onSelect: (Int) -> Void = { _ in }
    var onSeeAll: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trendar just nu")
                    .font(.title3.bold())
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !items.isEmpty {
                    Button("Visa alla", action: onSeeAll)
                        .font(.callout)
                        .foregroundStyle(.red)
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
                    Text("Inga trendande titlar just nu.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items.prefix(12)) { g in
                            Button { onSelect(g.id) } label: {
                                RecCard(
                                    title: g.title,
                                    subtitle: g.platformText,
                                    rating: g.rating / 2,
                                    imageURL: g.image,
                                    badge: g.badgeText
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 160, height: 100)
                .overlay(ProgressView().scaleEffect(0.7))

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.quaternarySystemFill))
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.quaternarySystemFill))
                    .frame(width: 80, height: 12)
            }
        }
    }
}
