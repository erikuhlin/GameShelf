//
//  TrendingSection.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//

import SwiftUI

struct TrendingSection: View {
    let items: [TrendingItem]
    var onSelect: (Int) -> Void = { _ in }
    var onSeeAll: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trendar just nu")
                    .font(.title3.bold())
                Spacer()
                Button("Visa alla", action: onSeeAll)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items.prefix(12)) { g in
                        Button { onSelect(g.id) } label: {
                            RecCard(
                                title: g.title,
                                subtitle: g.platformText,
                                rating: g.rating / 2,
                                imageURL: g.image
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
