//
//  SpelDNACard.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-31.
//

import SwiftUI

struct SpelDNACard: View {
    let profile: SpelDNAProfile?
    var onNavigateToLibrary: (() -> Void)? = nil

    var body: some View {
        if let p = profile {
            activeCard(p)
        } else {
            emptyCard
        }
    }

    // MARK: - Aktivt Spel-DNA Kort
    private func activeCard(_ p: SpelDNAProfile) -> some View {
        ZStack(alignment: .topTrailing) {
            // Mjuk glow i övre högra hörnet
            RadialGradient(
                colors: [p.accentColor.opacity(0.35), .clear],
                center: .center,
                startRadius: 5,
                endRadius: 110
            )
            .frame(width: 220, height: 220)
            .offset(x: 40, y: -40)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                // Ikon
                Text(p.icon)
                    .font(.system(size: 20))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .padding(.bottom, 12)

                // Eyebrow
                Text("DITT SPEL-DNA")
                    .font(.system(size: 10.5, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(p.accentColor)
                    .padding(.bottom, 4)

                // Titel
                Text(p.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.bottom, 8)

                // Beskrivning
                Text(p.description)
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .foregroundStyle(Color(hex: "#D9D3CC"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 14)

                // Statistik-chips
                HStack(spacing: 8) {
                    ForEach(p.supportingStats, id: \.self) { stat in
                        Text(stat)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .foregroundStyle(p.accentColor)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            LinearGradient(
                colors: [
                    p.accentColor.opacity(0.22),
                    Color(hex: "#14100F")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(p.accentColor.opacity(0.35), lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
    }

    // MARK: - Tomt Kort (< 5 spel)
    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.red)
                Text("DITT SPEL-DNA")
                    .font(.system(size: 10.5, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(Color.red)
            }

            Text("Lås upp ditt Spel-DNA")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Text("Lägg till minst 5 spel i ditt bibliotek för att analysera din spelsmak och generera din unika spelarprofil.")
                .font(.system(size: 12.5))
                .lineSpacing(3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let onNavigate = onNavigateToLibrary {
                Button {
                    onNavigate()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Gå till biblioteket")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1.0)
        )
    }
}
