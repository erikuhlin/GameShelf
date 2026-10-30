//
//  GameDiaryShareCardView.swift
//  gameshelf
//
//  Created by Antigravity on 2026-10-30.
//

import SwiftUI

// MARK: - Game Diary Year Share Card (Story / 9:16 format)
struct GameDiaryShareCardView: View {
    let year: Int
    let completedGames: [Game]
    let crownedGoty: Game?
    let username: String
    var preloadedCovers: [UUID: UIImage] = [:]

    private var totalHours: Int {
        completedGames.reduce(0) { total, g in
            let hours = max(Int(g.effectiveHoursPlayed), g.estimatedHours ?? 0)
            return total + hours
        }
    }

    private var averageRating: Double? {
        let rated = completedGames.compactMap { $0.rating }.filter { $0 > 0 }
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0, +)) / Double(rated.count)
    }

    private var topRatedGame: Game? {
        crownedGoty ?? completedGames.filter { ($0.rating ?? 0) > 0 }.max(by: { ($0.rating ?? 0) < ($1.rating ?? 0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Topp: GameShelf Branding & Speldagbok Tag
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.red)
                    Text("GameShelf")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.purple)
                    Text("SPELÅRET \(String(year))")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.purple.opacity(0.4), lineWidth: 0.8)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // 2. Statistik-trio
            HStack(spacing: 8) {
                statBox(
                    value: "\(completedGames.count)",
                    label: "Klarade spel",
                    icon: "checkmark.seal.fill",
                    color: .teal
                )
                statBox(
                    value: totalHours > 0 ? "\(totalHours)h" : "—",
                    label: "Speltid",
                    icon: "clock.fill",
                    color: .blue
                )
                statBox(
                    value: averageRating.map { String(format: "%.1f", $0) } ?? "—",
                    label: "Snittbetyg",
                    icon: "star.fill",
                    color: .yellow
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // 3. Topprankat / GOTY Highlight (om det finns)
            if let highlight = topRatedGame {
                HStack(spacing: 12) {
                    // Omslag
                    Group {
                        if let preloaded = preloadedCovers[highlight.id] {
                            Image(uiImage: preloaded)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if let url = highlight.coverURL {
                            CoverView(title: highlight.title, url: url, corner: 8, height: 62)
                        } else {
                            Color(hex: "#2C2C2E")
                                .overlay(
                                    Image(systemName: "gamecontroller.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.white.opacity(0.25))
                                )
                        }
                    }
                    .frame(width: 44, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(highlight.id == crownedGoty?.id ? "👑 ÅRETS SPEL" : "⭐ HÖGST BETYG")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(highlight.id == crownedGoty?.id ? Color(hex: "#FFB800") : .yellow)

                            if let r = highlight.rating, r > 0 {
                                Text("• \(r)/10")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }

                        Text(highlight.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if !highlight.genres.isEmpty {
                            Text(highlight.genres.prefix(2).joined(separator: " · "))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }
                .padding(10)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 0.8)
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // 4. Kollage av årets genomspelade spel
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.purple)
                        Text("GENOMSPELAT UNDER ÅRET")
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer()

                    Text("\(completedGames.count) spel")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                }

                if completedGames.isEmpty {
                    HStack {
                        Spacer()
                        Text("Inga genomspelade titlar loggade för \(String(year))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.vertical, 24)
                        Spacer()
                    }
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    let displayed = Array(completedGames.prefix(6))
                    let overflow = completedGames.count - displayed.count

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(displayed) { game in
                            miniDiaryCard(game: game)
                        }
                    }

                    if overflow > 0 {
                        HStack {
                            Spacer()
                            Text("+ \(overflow) fler spel klara under året")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.55))
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer(minLength: 10)

            // 5. Botten: Spelarens namn & branding
            HStack {
                if !username.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(username)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                Text("gameshelf.app")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(width: 340, height: 580)
        .background(
            ZStack {
                Color(red: 14/255, green: 13/255, blue: 26/255)

                // Subtil lila och röd glöd
                Circle()
                    .fill(Color.purple.opacity(0.24))
                    .blur(radius: 70)
                    .offset(x: -80, y: -120)

                Circle()
                    .fill(Color.red.opacity(0.18))
                    .blur(radius: 65)
                    .offset(x: 100, y: 130)

                Circle()
                    .fill(Color(hex: "#FFB800").opacity(0.12))
                    .blur(radius: 60)
                    .offset(x: 0, y: 200)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Stat Box
    @ViewBuilder
    private func statBox(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }

    // MARK: - Mini Diary Card
    @ViewBuilder
    private func miniDiaryCard(game: Game) -> some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let preloaded = preloadedCovers[game.id] {
                        Image(uiImage: preloaded)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let url = game.coverURL {
                        CoverView(title: game.title, url: url, corner: 8, height: 78)
                    } else {
                        Color(hex: "#2C2C2E")
                            .overlay(
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.white.opacity(0.25))
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1.5)

                if let r = game.rating, r > 0 {
                    HStack(spacing: 1.5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.yellow)
                        Text("\(r)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(3)
                }
            }

            Text(game.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

// MARK: - Game Diary Share Modal Sheet
struct GameDiaryShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    let year: Int
    let completedGames: [Game]
    let crownedGoty: Game?
    let username: String

    @State private var preloadedCovers: [UUID: UIImage] = [:]
    @State private var isRendering: Bool = false
    @State private var renderedImage: UIImage? = nil
    @State private var showingActivitySheet: Bool = false

    private var cardView: GameDiaryShareCardView {
        GameDiaryShareCardView(
            year: year,
            completedGames: completedGames,
            crownedGoty: crownedGoty,
            username: username,
            preloadedCovers: preloadedCovers
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                cardView
                    .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 12)

                Spacer()

                Button {
                    Task {
                        await renderAndShare()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRendering {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isRendering ? "Förbereder bild..." : "Dela eller spara bild")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.purple.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .disabled(isRendering)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Dela Spelåret")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Klar") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showingActivitySheet) {
                if let img = renderedImage {
                    ShareActivityView(activityItems: [img])
                }
            }
            .task {
                await preloadAllCovers()
            }
        }
    }

    private func preloadAllCovers() async {
        var images: [UUID: UIImage] = [:]

        await withTaskGroup(of: (UUID, UIImage?).self) { group in
            for game in completedGames {
                guard let url = game.coverURL else { continue }
                group.addTask {
                    if let cached = CoverImageCache.shared.image(for: url) {
                        return (game.id, cached)
                    }
                    if let (data, _) = try? await URLSession.shared.data(from: url),
                       let img = UIImage(data: data) {
                        CoverImageCache.shared.insert(img, data: data, for: url)
                        return (game.id, img)
                    }
                    return (game.id, nil)
                }
            }

            for await (id, img) in group {
                if let img = img {
                    images[id] = img
                }
            }
        }

        await MainActor.run {
            self.preloadedCovers = images
        }
    }

    @MainActor
    private func renderAndShare() async {
        isRendering = true
        defer { isRendering = false }

        if preloadedCovers.isEmpty {
            await preloadAllCovers()
        }

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = displayScale > 0 ? displayScale : 3.0

        if let uiImage = renderer.uiImage {
            self.renderedImage = uiImage
            self.showingActivitySheet = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}
