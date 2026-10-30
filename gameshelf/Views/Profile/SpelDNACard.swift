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
            VStack(alignment: .leading, spacing: 16) {
                activeCard(p)

                if !p.tiles.isEmpty {
                    dnaTilesGrid(p.tiles)
                }
            }
        } else {
            emptyCard
        }
    }

    // MARK: - Aktivt Spel-DNA Kort (Hero)
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
                // Topprad: Ikon & Dela-knapp
                HStack {
                    Text(p.icon)
                        .font(.system(size: 22))
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Spacer()

                    let shareText = "🧬 Mitt Spel-DNA på Gameshelf: \(p.icon) \(p.title)\n\n\(p.description)\n\n" + (p.secondaryArchetypes.isEmpty ? "" : "Sekundärt DNA: " + p.secondaryArchetypes.map { "\($0.icon) \($0.title) (\($0.matchPercentage)%)" }.joined(separator: ", ") + "\n\n") + "Utforska dina spelvanor på Gameshelf!"

                    ShareLink(item: shareText) {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .bold))
                            Text("Dela DNA")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 12)

                // Eyebrow
                Text("DITT SPEL-DNA • HUVUDARKETYP")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.2)
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

                // Sekundära arketyper / Hybrider
                if !p.secondaryArchetypes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SEKUNDÄRT DNA & HYBRID")
                            .font(.system(size: 9, weight: .black))
                            .tracking(1.0)
                            .foregroundStyle(.white.opacity(0.55))

                        HStack(spacing: 8) {
                            ForEach(p.secondaryArchetypes) { sub in
                                HStack(spacing: 5) {
                                    Text(sub.icon)
                                        .font(.system(size: 11))
                                    Text(sub.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("\(sub.matchPercentage)%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(sub.accentColor)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                )
                            }
                        }
                    }
                    .padding(.top, 14)
                }

                // Fotnot
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text("Viktat mot dina favoritspel, mästerverk och spelstil.")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 12)
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

    // MARK: - 4 Dynamiska DNA-Rutor
    private func dnaTilesGrid(_ tiles: [SpelDNATile]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("🧬")
                    .font(.caption)
                Text("DNA-profil & Dimensioner")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(tiles) { tile in
                    dnaTileView(tile)
                }
            }
        }
    }

    private func dnaTileView(_ tile: SpelDNATile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tile.category)
                    .font(.system(size: 8.5, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(tile.accentColor)
                    .lineLimit(1)

                Spacer()

                Text(tile.icon)
                    .font(.system(size: 14))
            }

            Text(tile.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(tile.subtitle)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(tile.accentColor)
                .lineLimit(1)

            Text(tile.detail)
                .font(.system(size: 10.5))
                .lineSpacing(2)
                .foregroundStyle(Color(hex: "#A39E98"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    tile.accentColor.opacity(0.10),
                    Color(hex: "#16161B")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tile.accentColor.opacity(0.25), lineWidth: 0.8)
        )
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
