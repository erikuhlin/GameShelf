//
//  ForYouHubView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-09-06.
//

import SwiftUI
import Combine

enum ForYouTab: String, CaseIterable, Identifiable {
    case recommendations = "🔮 Nya favoriter"
    case nostalgia = "⏳ Spelminnen & Nostalgi"

    var id: String { rawValue }
}

struct ForYouHubView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var profile: ProfileStore
    @StateObject private var engine = ForYouEngine.shared

    @State private var selectedTab: ForYouTab = .recommendations

    // Spelkompassen State
    @State private var selectedMood: CompassMood = .all
    @State private var selectedEra: CompassEra = .all
    @State private var selectedPlaytime: CompassPlaytime = .all
    @State private var selectedPlatformID: Int? = nil

    // Nostalgi Quick-Add Popover State
    @State private var activeNostalgiaGame: NostalgiaGameItem? = nil
    @State private var successToastText: String? = nil

    private var isCompassActive: Bool {
        selectedMood != .all || selectedEra != .all || selectedPlaytime != .all || selectedPlatformID != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Toppsektion: Titel, Spel-DNA & Flikväljare
                headerSection

                // 2. Spelkompassen (Guidande filter)
                spelkompassenBar

                // 3. Flikinnehåll
                switch selectedTab {
                case .recommendations:
                    if isCompassActive {
                        compassResultsView
                    } else {
                        curatedRecommendationsView
                    }
                case .nostalgia:
                    nostalgiaRadarView
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.ds.background.ignoresSafeArea())
        .navigationTitle("För dig")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await reloadCurrentTab(force: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(Color.ds.brandRed)
                }
            }
        }
        .task {
            await reloadCurrentTab(force: false)
        }
        .refreshable {
            await reloadCurrentTab(force: true)
        }
        .sheet(item: $activeNostalgiaGame) { item in
            NostalgiaAddSheet(
                item: item,
                onSave: { newGame in
                    store.add(newGame)
                    engine.removeNostalgiaItem(id: item.game.id)
                    showToast("Lagt till \"\(newGame.title)\" som klarat!")
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .bottom) {
            if let toast = successToastText {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(toast)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.85), in: Capsule())
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - 1. Header & Flikväljare
    private var headerSection: some View {
        VStack(spacing: 14) {
            // Segmented Flikväljare överst med tydlig placering
            Picker("Välj flik", selection: $selectedTab) {
                ForEach(ForYouTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 6)
            .onChange(of: selectedTab) { _ in
                Task {
                    await reloadCurrentTab(force: false)
                }
            }

            // Spel-DNA Hero-kort om det finns beräknat
            if let dna = engine.fingerprint?.spelDNA ?? SpelDNACalculator.calculate(games: store.games, playFor: profile.playFor) {
                HStack(spacing: 12) {
                    Text(dna.icon)
                        .font(.system(size: 30))
                        .padding(8)
                        .background(dna.accentColor.opacity(0.16), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("DITT SPEL-DNA")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(dna.accentColor)
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(dna.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                        }

                        Text(dna.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(dna.accentColor.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 2. Spelkompassen Filter Bar
    private var spelkompassenBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "safari")
                        .foregroundStyle(Color.ds.brandRed)
                    Text("Spelkompassen")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }

                Spacer()

                if isCompassActive {
                    Button("Återställ") {
                        withAnimation {
                            selectedMood = .all
                            selectedEra = .all
                            selectedPlaytime = .all
                            selectedPlatformID = nil
                        }
                        Task {
                            if selectedTab == .recommendations {
                                await engine.loadPersonalizedRecommendations(games: store.games, profile: profile)
                            } else {
                                await engine.loadNostalgiaRadar(games: store.games, profile: profile, era: .all, platformID: nil, forceReload: true)
                            }
                        }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.ds.brandRed)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Humör / Känsla
                    Menu {
                        ForEach(CompassMood.allCases) { mood in
                            Button {
                                selectedMood = mood
                                triggerCompass()
                            } label: {
                                Label(mood.rawValue, systemImage: mood.icon)
                            }
                        }
                    } label: {
                        filterChip(
                            title: selectedMood == .all ? "Känsla" : selectedMood.rawValue,
                            icon: selectedMood.icon,
                            isActive: selectedMood != .all
                        )
                    }

                    // Epok / Era
                    Menu {
                        ForEach(CompassEra.allCases) { era in
                            Button {
                                selectedEra = era
                                triggerCompass()
                            } label: {
                                Label(era.rawValue, systemImage: era.icon)
                            }
                        }
                    } label: {
                        filterChip(
                            title: selectedEra == .all ? "Epok" : selectedEra.rawValue,
                            icon: selectedEra.icon,
                            isActive: selectedEra != .all
                        )
                    }

                    // Konsol / Plattform
                    Menu {
                        Button("Alla konsoler") {
                            selectedPlatformID = nil
                            triggerCompass()
                        }
                        Divider()
                        ForEach(CompassPlatformOption.allPlatforms) { p in
                            Button {
                                selectedPlatformID = p.id
                                triggerCompass()
                            } label: {
                                Label(p.name, systemImage: p.icon)
                            }
                        }
                    } label: {
                        let currentPlat = CompassPlatformOption.allPlatforms.first(where: { $0.id == selectedPlatformID })
                        filterChip(
                            title: currentPlat?.name ?? "Plattform",
                            icon: currentPlat?.icon ?? "gamecontroller",
                            isActive: selectedPlatformID != nil
                        )
                    }

                    // Speltid
                    Menu {
                        ForEach(CompassPlaytime.allCases) { pt in
                            Button {
                                selectedPlaytime = pt
                                triggerCompass()
                            } label: {
                                Label(pt.rawValue, systemImage: pt.icon)
                            }
                        }
                    } label: {
                        filterChip(
                            title: selectedPlaytime == .all ? "Speltid" : selectedPlaytime.rawValue,
                            icon: selectedPlaytime.icon,
                            isActive: selectedPlaytime != .all
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func filterChip(title: String, icon: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title)
                .font(.caption.bold())
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .opacity(0.6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isActive ? Color.ds.brandRed : Color(.secondarySystemGroupedBackground))
        .foregroundStyle(isActive ? .white : .primary)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isActive ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func triggerCompass() {
        Task {
            if selectedTab == .recommendations {
                await engine.applyCompass(
                    games: store.games,
                    profile: profile,
                    mood: selectedMood,
                    playtime: selectedPlaytime,
                    era: selectedEra,
                    platformID: selectedPlatformID
                )
            } else {
                await engine.loadNostalgiaRadar(
                    games: store.games,
                    profile: profile,
                    era: selectedEra,
                    platformID: selectedPlatformID,
                    forceReload: true
                )
            }
        }
    }

    // MARK: - 3A. Flik 1: Kurerade Nya favoriter
    private var curatedRecommendationsView: some View {
        VStack(spacing: 24) {
            if engine.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Skräddarsyr rekommendationer utifrån dina spel...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 40)
            } else if engine.curatedSections.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Inga rekommendationer kunde laddas just nu")
                        .font(.headline)
                    Text("Testa att uppdatera eller välj filter i Spelkompassen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 40)
            } else {
                ForEach(engine.curatedSections) { section in
                    curatedSectionView(section)
                }
            }
        }
    }

    private func curatedSectionView(_ section: ForYouCuratedSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: section.icon)
                    .font(.subheadline)
                    .foregroundStyle(section.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.badge.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(section.accentColor)
                    Text(section.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Interaktiva valbara knappar
                switch section.kind {
                case .referenceGame(let slot, let currentGame):
                    Menu {
                        Text("Välj ett annat referensspel:")
                        ForEach(engine.availableReferenceGames) { g in
                            Button {
                                Task {
                                    await engine.changeReferenceGame(slot: slot, newGame: g)
                                }
                            } label: {
                                HStack {
                                    Text(g.title)
                                    if g.id == currentGame.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Byt spel")
                            Image(systemName: "arrow.2.squarepath")
                                .font(.caption2)
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Color.ds.brandRed)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.ds.brandRed.opacity(0.12), in: Capsule())
                    }

                case .studio(let currentStudio):
                    Menu {
                        Text("Välj en annan studio:")
                        ForEach(engine.availableStudios, id: \.self) { studio in
                            Button {
                                Task {
                                    await engine.changeStudio(newStudio: studio)
                                }
                            } label: {
                                HStack {
                                    Text(studio)
                                    if studio == currentStudio {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Byt studio")
                            Image(systemName: "arrow.2.squarepath")
                                .font(.caption2)
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.14), in: Capsule())
                    }

                case .spelDNA(let currentFocus):
                    Menu {
                        Text("Fokusera förslag:")
                        Button {
                            Task { await engine.changeDNAFocus(newFocus: "modern") }
                        } label: {
                            HStack {
                                Text("Moderna storspel")
                                if currentFocus == "modern" { Image(systemName: "checkmark") }
                            }
                        }
                        Button {
                            Task { await engine.changeDNAFocus(newFocus: "highest_rated") }
                        } label: {
                            HStack {
                                Text("Kritiskt hyllade (85+)")
                                if currentFocus == "highest_rated" { Image(systemName: "checkmark") }
                            }
                        }
                        Button {
                            Task { await engine.changeDNAFocus(newFocus: "classic") }
                        } label: {
                            HStack {
                                Text("Gyllene klassiker")
                                if currentFocus == "classic" { Image(systemName: "checkmark") }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(dnaFocusLabel(currentFocus))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .font(.caption.bold())
                        .foregroundStyle(section.accentColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(section.accentColor.opacity(0.14), in: Capsule())
                    }

                case .topRated:
                    EmptyView()
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(section.games) { game in
                        gameDiscoveryCard(game: game, badge: section.badge)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }

    private func gameDiscoveryCard(game: IGDBGame, badge: String) -> some View {
        let isInWishlist = store.games.contains {
            ($0.igdbID == game.id || $0.title.lowercased() == game.name.lowercased()) && !$0.isOwned
        }
        let isOwned = store.games.contains {
            ($0.igdbID == game.id || $0.title.lowercased() == game.name.lowercased()) && $0.isOwned
        }

        return NavigationLink(destination: GameDetailView(igdbID: game.id)) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    CoverView(title: game.name, url: game.coverURL, corner: 12, height: 140)
                        .frame(width: 105, height: 140)
                        .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)

                    if let rating = game.totalRating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.0f", rating))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.75), in: Capsule())
                        .padding(5)
                    }
                }

                Text(game.name)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 105, height: 32, alignment: .topLeading)

                HStack {
                    if let year = game.releaseYear {
                        Text(String(year))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !isOwned {
                        Button {
                            toggleWishlist(game: game)
                        } label: {
                            Image(systemName: isInWishlist ? "bookmark.fill" : "bookmark")
                                .font(.caption)
                                .foregroundStyle(isInWishlist ? Color.ds.brandRed : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 105)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3B. Spelkompassen Filtrerade Resultat
    private var compassResultsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RESULTAT FRÅN SPELKOMPASSEN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.ds.brandRed)
                    Text("\(engine.compassResults.count) träffar matchar dina val")
                        .font(.headline)
                }
                Spacer()
            }
            .padding(.horizontal)

            if engine.isLoadingCompass {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if engine.compassResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Inga spel matchade kombinationen")
                        .font(.subheadline.bold())
                    Text("Prova att bredda din sökning genom att ändra eller nollställa något filter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 14)], spacing: 16) {
                    ForEach(engine.compassResults) { game in
                        gameDiscoveryCard(game: game, badge: "Kompassen")
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 3C. Flik 2: Spelminnen & Nostalgi Radar
    private var nostalgiaRadarView: some View {
        VStack(spacing: 16) {
            // Informationskort
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .padding(10)
                    .background(Color.yellow.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Har du glömt att logga dessa? 🎮")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Hyllade klassiker från dina genrer som saknas i biblioteket. Markera spel du spelat för att komplettera din samling.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)

            // Nostalgikort
            if engine.nostalgiaItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    Text("Din spelhistorik ser komplett ut!")
                        .font(.headline)
                    Text("Inga fler ologgade klassiker hittades för det valda filtret.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(engine.nostalgiaItems) { item in
                        nostalgiaCard(item: item)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func nostalgiaCard(item: NostalgiaGameItem) -> some View {
        let game = item.game

        return HStack(spacing: 14) {
            NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                CoverView(title: game.name, url: game.coverURL, corner: 10, height: 110)
                    .frame(width: 80, height: 110)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.nostalgiaReason)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.18), in: Capsule())
                        .foregroundStyle(.yellow)

                    Spacer()

                    Button {
                        engine.removeNostalgiaItem(id: game.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(game.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(game.releaseYear.map(String.init) ?? "Okänt") • \(item.platformLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                HStack(spacing: 8) {
                    // Knappen "Har spelat! 🏆"
                    Button {
                        activeNostalgiaGame = item
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.caption2)
                            Text("Har spelat!")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundStyle(.yellow)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Knappen "Vill spela 🔖"
                    Button {
                        toggleWishlist(game: game)
                        engine.removeNostalgiaItem(id: game.id)
                        showToast("Lagt till \"\(game.name)\" i önskelistan!")
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bookmark")
                                .font(.caption2)
                            Text("Vill spela")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Handlers & Helper Logic
    private func reloadCurrentTab(force: Bool) async {
        if selectedTab == .recommendations {
            if isCompassActive {
                await engine.applyCompass(
                    games: store.games,
                    profile: profile,
                    mood: selectedMood,
                    playtime: selectedPlaytime,
                    era: selectedEra,
                    platformID: selectedPlatformID
                )
            } else {
                await engine.loadPersonalizedRecommendations(games: store.games, profile: profile, forceReload: force)
            }
        } else {
            await engine.loadNostalgiaRadar(
                games: store.games,
                profile: profile,
                era: selectedEra,
                platformID: selectedPlatformID,
                forceReload: force
            )
        }
    }

    private func toggleWishlist(game: IGDBGame) {
        let isInWishlist = store.games.contains {
            ($0.igdbID == game.id || $0.title.lowercased() == game.name.lowercased()) && !$0.isOwned
        }

        if isInWishlist {
            if let existing = store.games.first(where: { $0.igdbID == game.id || $0.title.lowercased() == game.name.lowercased() }) {
                store.delete(existing)
            }
        } else {
            let availablePlats = game.platforms?.map(\.name) ?? []
            let matchedPlats = PlatformMatcher.resolvePlatforms(availableIGDBPlatforms: availablePlats)

            let newGame = Game(
                title: game.name,
                platforms: matchedPlats,
                releaseYear: game.releaseYear ?? 0,
                genres: game.genres?.map(\.name) ?? [],
                developers: game.developerName.map { [$0] } ?? [],
                status: .notStarted,
                rating: 0,
                igdbRating: game.totalRating.map { $0 / 10 },
                coverURL: game.coverURL,
                igdbID: game.id,
                firstReleaseDate: game.firstReleaseDate,
                isOwned: false
            )
            store.add(newGame)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func showToast(_ text: String) {
        withAnimation {
            successToastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                if successToastText == text {
                    successToastText = nil
                }
            }
        }
    }

    private func dnaFocusLabel(_ focus: String) -> String {
        switch focus {
        case "highest_rated": return "Högst betyg"
        case "classic": return "Klassiker"
        default: return "Moderna"
        }
    }
}

// MARK: - Quick-Add Sheet för Spelminnen & Nostalgi
struct NostalgiaAddSheet: View {
    let item: NostalgiaGameItem
    var onSave: (Game) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlatform: String
    @State private var userRating: Int = 8
    @State private var completedYear: Int
    @State private var personalNote: String = ""

    init(item: NostalgiaGameItem, onSave: @escaping (Game) -> Void) {
        self.item = item
        self.onSave = onSave

        let available = item.game.platforms?.map(\.name) ?? []
        let matched = PlatformMatcher.resolvePlatforms(availableIGDBPlatforms: available)
        _selectedPlatform = State(initialValue: matched.first ?? "PlayStation")
        _completedYear = State(initialValue: item.game.releaseYear ?? Calendar.current.component(.year, from: Date()))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Header med spelinfo
                Section {
                    HStack(spacing: 14) {
                        CoverView(title: item.game.name, url: item.game.coverURL, corner: 8, height: 80)
                            .frame(width: 60, height: 80)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.game.name)
                                .font(.headline)
                                .lineLimit(2)

                            if let dev = item.game.developerName {
                                Text(dev)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let year = item.game.releaseYear {
                                Text("Släpptes \(String(year))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Vilken plattform spelade du på?
                Section("Plattform du spelade på") {
                    let available = item.game.platforms?.map(\.name) ?? []
                    if available.count > 1 {
                        Picker("Välj plattform", selection: $selectedPlatform) {
                            ForEach(available, id: \.self) { plat in
                                Text(plat).tag(plat)
                            }
                        }
                    } else {
                        HStack {
                            Text("Plattform")
                            Spacer()
                            Text(selectedPlatform)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Betyg
                Section("Ditt betyg (1–10)") {
                    VStack(spacing: 12) {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(userRating > 0 ? "\(userRating) / 10" : "Inget betyg")
                                    .font(.headline)
                            }

                            Spacer()

                            if userRating > 0 {
                                Text(ratingLabel(userRating))
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.ds.brandRed)
                            }
                        }

                        // Stjärnrad
                        HStack(spacing: 8) {
                            ForEach(1...10, id: \.self) { star in
                                Image(systemName: star <= userRating ? "star.fill" : "star")
                                    .font(.system(size: 18))
                                    .foregroundStyle(star <= userRating ? .yellow : Color(.systemGray4))
                                    .onTapGesture {
                                        userRating = star
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                    }
                }

                // När klarade du spelet?
                Section("Ungefärligt år du klarade det") {
                    Stepper(value: $completedYear, in: 1980...Calendar.current.component(.year, from: Date())) {
                        HStack {
                            Text("År:")
                            Text(String(completedYear))
                                .font(.headline)
                                .foregroundStyle(Color.ds.brandRed)
                        }
                    }
                }

                // Minnesanteckning
                Section("Personligt minne / anteckning (valfritt)") {
                    TextField("T.ex. Spelade sönder detta under sommarlovet...", text: $personalNote, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Lägg till spelminne")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara som Klarat 🏆") {
                        saveGame()
                    }
                    .font(.headline)
                    .foregroundStyle(.yellow)
                }
            }
        }
    }

    private func ratingLabel(_ r: Int) -> String {
        switch r {
        case 10: return "Mästerverk"
        case 9: return "Fantastiskt"
        case 8: return "Mycket bra"
        case 7: return "Bra"
        case 6: return "Helt okej"
        case 5: return "Medelmåttigt"
        default: return "Svagt"
        }
    }

    private func saveGame() {
        let game = item.game
        let newGame = Game(
            title: game.name,
            platforms: [selectedPlatform],
            releaseYear: game.releaseYear ?? 0,
            genres: game.genres?.map(\.name) ?? [],
            developers: game.developerName.map { [$0] } ?? [],
            status: .completed,
            rating: userRating > 0 ? userRating : nil,
            igdbRating: game.totalRating.map { $0 / 10 },
            coverURL: game.coverURL,
            igdbID: game.id,
            firstReleaseDate: game.firstReleaseDate,
            isOwned: true,
            notes: personalNote,
            completedYear: completedYear,
            completedDate: Date()
        )

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSave(newGame)
        dismiss()
    }
}
