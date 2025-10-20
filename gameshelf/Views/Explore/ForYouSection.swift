//
//  ForYouSection.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//



import SwiftUI

// Local helpers (extracted from ExploreView)
@ViewBuilder
private func sectionHeader(title: String) -> some View {
    HStack {
        Text(title).font(.title3.bold())
        Spacer()
    }
    .padding(.horizontal)
}

@ViewBuilder
private func hint(_ text: String) -> some View {
    Text(text)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
}

struct ForYouSection: View {
    let prefs: ExplorePrefs

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Recommended for you")
            if prefs.platforms.isEmpty {
                hint("Personalize in your profile to refine recommendations.")
            } else {
                hint("Based on: \(prefs.platforms.joined(separator: ", ")) · Age \(prefs.minAge)")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sampleGames(for: prefs), id: \.title) { g in
                        RecCard(title: g.title, subtitle: g.platform, rating: Double(g.rating), imageURL: nil)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
