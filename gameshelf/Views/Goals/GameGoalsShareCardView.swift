//
//  GameGoalsShareCardView.swift
//  gameshelf
//
//  Created by Antigravity on 2026-10-30.
//

import SwiftUI

// MARK: - Game Goals Share Card (Instagram Story / 9:16 format)
struct GameGoalsShareCardView: View {
    let year: Int
    let completedCount: Int
    let annualGoal: Int
    let completedGames: [Game]
    let focusGames: [Game]
    let tempoText: String?
    let username: String
    var preloadedCovers: [UUID: UIImage] = [:]

    private var progressRatio: Double {
        guard annualGoal > 0 else { return 0 }
        return min(max(Double(completedCount) / Double(annualGoal), 0.0), 1.0)
    }

    private var percentage: Int {
        Int(round(progressRatio * 100))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Topp: GameShelf Branding & Spelmål Tag
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
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#FFB800"))
                    Text("SPELMÅL \(String(year))")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "#FFB800").opacity(0.3), lineWidth: 0.8)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // 2. Hero Progress Section
            VStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 6) {
                    Text("\(completedCount)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(hex: "#FFD54F")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("/ \(annualGoal)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 6)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(percentage)%")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "#FFB800"))

                        Text(completedCount >= annualGoal ? "Målet nått! 🎉" : "\(max(0, annualGoal - completedCount)) kvar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 7)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color(hex: "#FF9500"), Color(hex: "#FFD54F")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(7, geo.size.width * CGFloat(progressRatio)), height: 7)
                    }
                }
                .frame(height: 7)

                if let tempo = tempoText, !tempo.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "#FFB800"))
                        Text(tempo)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
            )
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // 3. Sektion: Klarade spel i år
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.teal)
                        Text("KLARADE I ÅR")
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer()

                    Text("\(completedGames.count) st")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                }

                if completedGames.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "gamecontroller")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("Inga klara spel än — året är ungt!")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.vertical, 16)
                        Spacer()
                    }
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    let displayedCompleted = Array(completedGames.prefix(4))
                    let overflow = completedGames.count - displayedCompleted.count

                    HStack(spacing: 8) {
                        ForEach(displayedCompleted) { game in
                            miniGamePoster(game: game, isCompleted: true)
                        }

                        if overflow > 0 {
                            VStack(spacing: 3) {
                                Text("+\(overflow)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("fler")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                        }
                    }
                    .frame(height: 98)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // 4. Sektion: Kvar i listan / Fokus just nu
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("KVAR I LISTAN · FOKUS")
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer()

                    Text("\(focusGames.count) spel")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                }

                if focusGames.isEmpty {
                    HStack {
                        Spacer()
                        Text("Inga fokusspel valda just nu")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.vertical, 16)
                        Spacer()
                    }
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 6) {
                        ForEach(focusGames.prefix(3)) { game in
                            focusGameRow(game: game)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer(minLength: 10)

            // 5. Botten: Spelarens namn & GameShelf iOS-stämpel
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
                Color(red: 12/255, green: 16/255, blue: 28/255)

                // Bakgrundsglöd (Guld och rött)
                Circle()
                    .fill(Color(hex: "#FF9500").opacity(0.2))
                    .blur(radius: 65)
                    .offset(x: 100, y: -130)

                Circle()
                    .fill(Color.red.opacity(0.22))
                    .blur(radius: 70)
                    .offset(x: -90, y: 140)

                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .blur(radius: 60)
                    .offset(x: 70, y: 190)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Mini Poster för klarade spel
    @ViewBuilder
    private func miniGamePoster(game: Game, isCompleted: Bool) -> some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let preloaded = preloadedCovers[game.id] {
                        Image(uiImage: preloaded)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let url = game.coverURL {
                        CoverView(title: game.title, url: url, corner: 8, height: 74)
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
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

                // Rating eller checkmark
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
                } else if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.teal)
                        .background(Color.black.opacity(0.7), in: Circle())
                        .padding(3)
                }
            }

            Text(game.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Fokusrad för kvarvarande spel
    @ViewBuilder
    private func focusGameRow(game: Game) -> some View {
        let progress = GamingGoalEngine.calculateProgress(for: game)
        let pct = progress.percentage

        HStack(spacing: 8) {
            // Litet omslag
            Group {
                if let preloaded = preloadedCovers[game.id] {
                    Image(uiImage: preloaded)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let url = game.coverURL {
                    CoverView(title: game.title, url: url, corner: 6, height: 38)
                } else {
                    Color(hex: "#2C2C2E")
                        .overlay(
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.25))
                        )
                }
            }
            .frame(width: 28, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Liten framstegsbar om uppdrag finns
                if progress.hasTasks && progress.totalTasks > 0 {
                    HStack(spacing: 6) {
                        GeometryReader { barGeo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                Capsule()
                                    .fill(Color(hex: "#FF9500"))
                                    .frame(width: max(3, barGeo.size.width * CGFloat(min(1.0, Double(pct) / 100.0))))
                            }
                        }
                        .frame(height: 3.5)

                        Text("\(pct)%")
                            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "#FF9500"))
                    }
                } else {
                    Text(game.status.title(isMultiplayerOrOngoing: game.isMultiplayerOrOngoing))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Game Goals Share Modal Sheet
struct GameGoalsShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    let year: Int
    let completedCount: Int
    let annualGoal: Int
    let completedGames: [Game]
    let focusGames: [Game]
    let tempoText: String?
    let username: String

    @State private var preloadedCovers: [UUID: UIImage] = [:]
    @State private var isRendering: Bool = false
    @State private var renderedImage: UIImage? = nil
    @State private var showingActivitySheet: Bool = false

    private var cardView: GameGoalsShareCardView {
        GameGoalsShareCardView(
            year: year,
            completedCount: completedCount,
            annualGoal: annualGoal,
            completedGames: completedGames,
            focusGames: focusGames,
            tempoText: tempoText,
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
                            colors: [Color.red, Color(hex: "#FF9500")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.red.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .disabled(isRendering)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Dela Spelmål")
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
        let allGames = completedGames + focusGames
        var images: [UUID: UIImage] = [:]

        await withTaskGroup(of: (UUID, UIImage?).self) { group in
            for game in allGames {
                guard let url = game.coverURL else { continue }
                group.addTask {
                    if let cached = await CoverImageCache.shared.image(for: url) {
                        return (game.id, cached)
                    }
                    if let (data, _) = try? await URLSession.shared.data(from: url),
                       let img = UIImage(data: data) {
                        await CoverImageCache.shared.insert(img, data: data, for: url)
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

        // Om omslagsbilder laddas in, säkerställ att vi har dem
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
