//
//  ProfilePreferencesSheet.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-10-08.
//

import SwiftUI

struct ProfilePreferencesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profile: ProfileStore

    let availablePlatforms: [String]
    let genreOptions: [String]
    let playForOptions: [String]
    let playstyleOptions: [String]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // 1. Min Setup / Plattformar
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Text("🎮")
                            Text("Min setup & konsoler")
                                .font(.headline)
                        }
                        Text("Välj de plattformar du spelar på aktivt för personliga rekommendationer.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(availablePlatforms, id: \.self) { plat in
                                let isSelected = profile.platforms.contains(plat)
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        profile.toggle(plat)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .black))
                                                .foregroundStyle(Color.red)
                                        }
                                        Text(plat)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(isSelected ? Color.primary : .secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        isSelected ? Color.red.opacity(0.12) : Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isSelected ? Color.red.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1.0)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // 2. Favoritgenrer
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Text("❤️")
                            Text("Favoritgenrer")
                                .font(.headline)
                        }
                        Text("Styr vilka genrer som prioriteras i ditt Spel-DNA och i sökförslagen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(genreOptions, id: \.self) { genre in
                                let isSelected = profile.favoriteGenres.contains(genre)
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        profile.toggleGenre(genre)
                                    }
                                } label: {
                                    Text(genre)
                                        .font(.system(size: 12.5, weight: .bold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            isSelected ? Color.red : Color(.secondarySystemGroupedBackground),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(isSelected ? Color.white : .secondary)
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color.red : Color.white.opacity(0.08), lineWidth: 1.0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // 3. Spelstil
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Text("🕹️")
                            Text("Min spelstil")
                                .font(.headline)
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(playstyleOptions, id: \.self) { style in
                                let isSelected = profile.playstyle.contains(style)
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        profile.togglePlaystyle(style)
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .black))
                                        }
                                        Text(style)
                                            .font(.system(size: 12.5, weight: .bold))
                                    }
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 7)
                                    .background(
                                        isSelected ? Color.red.opacity(0.18) : Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .foregroundStyle(isSelected ? Color.red : .secondary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(isSelected ? Color.red.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1.0)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // 4. Spelmotiv
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Text("✨")
                            Text("Jag spelar helst för")
                                .font(.headline)
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(playForOptions, id: \.self) { motive in
                                let isSelected = profile.playFor.contains(motive)
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        profile.togglePlayFor(motive)
                                    }
                                } label: {
                                    Text(motive)
                                        .font(.system(size: 12.5, weight: .bold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            isSelected ? Color.red : Color(.secondarySystemGroupedBackground),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(isSelected ? Color.white : .secondary)
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color.red : Color.white.opacity(0.08), lineWidth: 1.0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Spelpreferenser & Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") {
                        dismiss()
                    }
                    .bold()
                    .foregroundStyle(Color.red)
                }
            }
        }
    }
}

// MARK: - FlowLayout Helper för responsiva tagg-chips
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: width, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
