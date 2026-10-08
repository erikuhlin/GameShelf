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
    let playingMoodOptions: [String]

    private func platformIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("pc") || lower.contains("windows") { return "desktopcomputer" }
        if lower.contains("mac") { return "laptopcomputer" }
        if lower.contains("steam deck") || lower.contains("handheld") { return "gamecontroller" }
        if lower.contains("switch") || lower.contains("3ds") || lower.contains("ds") || lower.contains("game boy") { return "arcade.stick.console" }
        if lower.contains("mobil") || lower.contains("ipad") || lower.contains("ios") { return "iphone.gen3" }
        if lower.contains("vr") || lower.contains("quest") { return "visionpro" }
        if lower.contains("playstation") || lower.contains("ps") || lower.contains("xbox") { return "gamecontroller.fill" }
        if lower.contains("retro") { return "arcade.stick" }
        return "gamecontroller"
    }

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
                        Text("Välj de plattformar du spelar på aktivt för personliga rekommendationer och biblioteksanpassning.")
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
                                        Image(systemName: platformIcon(for: plat))
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(isSelected ? Color.blue : .secondary)

                                        Text(plat)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(isSelected ? Color.primary : .secondary)

                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .black))
                                                .foregroundStyle(Color.blue)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        isSelected ? Color.blue.opacity(0.12) : Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isSelected ? Color.blue.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1.0)
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
                                    HStack(spacing: 5) {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .black))
                                        }
                                        Text(genre)
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 7)
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
                        Text("Hur du föredrar att ta dig an dina spel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

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
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 7)
                                    .background(
                                        isSelected ? Color.orange.opacity(0.18) : Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .foregroundStyle(isSelected ? Color.orange : .secondary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(isSelected ? Color.orange.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1.0)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // 4. Spelmotiv / Vad jag spelar för
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Text("💡")
                            Text("Jag spelar helst för")
                                .font(.headline)
                        }
                        Text("Känslorna och upplevelserna som driver dig att starta ett spel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(playForOptions, id: \.self) { motive in
                                let isSelected = profile.playFor.contains(motive)
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        profile.togglePlayFor(motive)
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .black))
                                        }
                                        Text(motive)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 7)
                                    .background(
                                        isSelected ? Color.purple.opacity(0.2) : Color(.secondarySystemGroupedBackground),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(isSelected ? Color.purple : .secondary)
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.purple.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1.0)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // 5. Nuvarande Spelhumör & Vibe
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Text("✨")
                            Text("Aktuellt spelhumör & vibe")
                                .font(.headline)
                        }
                        Text("Sätt tonen för vad du är sugen på att spela just nu (visas på din profil).")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(playingMoodOptions, id: \.self) { mood in
                                let isSelected = profile.playingMood == mood
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        if profile.playingMood == mood {
                                            profile.playingMood = ""
                                        } else {
                                            profile.playingMood = mood
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isSelected {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        Text(mood)
                                            .font(.system(size: 12.5, weight: .semibold))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        isSelected ? Color.teal.opacity(0.2) : Color(.secondarySystemGroupedBackground),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(isSelected ? Color.teal : .secondary)
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.teal.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1.0)
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
