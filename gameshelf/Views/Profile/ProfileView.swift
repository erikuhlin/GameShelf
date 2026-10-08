//
//  ProfileView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-08.
//

import SwiftUI

enum ProfileTab: String, CaseIterable, Identifiable {
    case profile = "Profil"
    case diary = "Speldagbok"
    case activity = "Statistik"

    var id: String { rawValue }
}

struct ProfileView: View {
    @EnvironmentObject var profile: ProfileStore
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ProfileTab = .profile
    @State private var showingSettingsSheet = false
    @State private var showingProfileSwitcher = false
    @State private var showingPairingSheet = false
    @State private var showingAccountSyncSheet = false
    @State private var showingAvatarPicker = false
    @State private var showingWrappedSheet = false
    @State private var showingPreferencesSheet = false
    @State private var wrappedSelectedYear: Int? = nil
    @State private var isEditingIdentity = false
    @State private var tempUsername = ""
    @State private var tempAgeString = ""

    @State private var tempGamerBio = ""

    // Utökade plattformar för "Min setup"
    private let availablePlatforms = [
        "PlayStation 5",
        "PlayStation 4",
        "PlayStation 3",
        "PlayStation 2",
        "Xbox Series X|S",
        "Xbox One",
        "Xbox 360",
        "Nintendo Switch",
        "Nintendo 3DS / DS",
        "Game Boy / GBA",
        "PC / Windows",
        "Steam Deck / Handheld PC",
        "Mac",
        "Mobil / iPad",
        "VR (Quest / PS VR2)",
        "Retro / Emulering"
    ]

    // Utökade standardgenrer för "Mina spelpreferenser"
    private let genreOptions = [
        "RPG",
        "Action",
        "Action-RPG",
        "Soulslike",
        "Skräck",
        "Survival Horror",
        "FPS",
        "Äventyr",
        "Öppen värld",
        "Strategi",
        "Roguelike",
        "Survival",
        "Metroidvania",
        "JRPG",
        "Simulator",
        "Plattform",
        "Pussel",
        "Sport",
        "Racing",
        "Fighting",
        "Indie",
        "Cozy & Life Sim",
        "Hack & Slash",
        "Smygspel",
        "Berättelsedrivet",
        "Immersive Sim",
        "Deckbuilder",
        "Cyberpunk / Sci-Fi",
        "MMO"
    ]

    // Utökade spelmotiv
    private let playForOptions = [
        "Story & Karaktärer",
        "Utforskning",
        "Action & Tempo",
        "Tävling & Ranking",
        "Avkoppling & Lugn",
        "Utmaning & Bemästring",
        "Kreativitet & Byggande",
        "Samarbete & Gemenskap",
        "Djup Lore & Världsbygge",
        "Immersion & Stämning",
        "Mästra svåra bossar",
        "Filmatisk upplevelse",
        "Nostalgi & Retro",
        "100% Completionism",
        "Snabba sessioner",
        "Adrenalin & Puls",
        "Taktik & Problemlösning"
    ]

    // Min Spelstil
    private let playstyleOptions = [
        "Singleplayer",
        "Story-fokuserad",
        "Co-op / Samarbete",
        "PvP / Multiplayer",
        "Trophy / Achievement Hunter",
        "Completionist (100%)",
        "Hardcore / Utmanare",
        "Casual & Cozy",
        "Utforskare & Samlare",
        "Taktiker & Strateg",
        "Speedrunner"
    ]

    // Aktuellt spelhumör
    private let playingMoodOptions = [
        "🧭 Utforska nya världar",
        "☕ Mysigt & Avkopplande",
        "⚔️ Brutal bossutmaning",
        "📖 Djup story & lore",
        "⚡ Snabba matcher & action",
        "🧠 Klurig taktik & hjärngympa",
        "👾 Nostalgisk tidsresa"
    ]

    // Dynamiskt beräknat Spel-DNA
    private var computedSpelDNA: SpelDNAProfile? {
        SpelDNACalculator.calculate(games: store.games, playFor: profile.playFor)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toppväxlare mellan Profil och Aktivitet
                Picker("Vy", selection: $selectedTab) {
                    ForEach(ProfileTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(.systemGroupedBackground))

                // Innehållsvy
                Group {
                    switch selectedTab {
                    case .profile:
                        profileScrollView
                    case .diary:
                        GameDiaryView()
                    case .activity:
                        ActivityView(isEmbedded: true)
                    }
                }
                .frame(maxWidth: 880)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingProfileSwitcher = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("Byt profil")
                                .font(.subheadline.bold())
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Color(.secondarySystemGroupedBackground), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingProfileSwitcher) {
                ProfileSwitcherView()
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingPairingSheet) {
                DevicePairingView()
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingAccountSyncSheet) {
                AccountSyncSheet()
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingSettingsSheet) {
                ProfileSettingsSheet()
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingWrappedSheet) {
                YearWrappedSheet(initialYear: wrappedSelectedYear)
            }
            .sheet(isPresented: $showingAvatarPicker) {
                AvatarPickerSheet()
                    .environmentObject(profile)
            }
            .sheet(isPresented: $isEditingIdentity) {
                editIdentitySheet
            }
            .sheet(isPresented: $showingPreferencesSheet) {
                ProfilePreferencesSheet(
                    availablePlatforms: availablePlatforms,
                    genreOptions: genreOptions,
                    playForOptions: playForOptions,
                    playstyleOptions: playstyleOptions,
                    playingMoodOptions: playingMoodOptions
                )
                .environmentObject(profile)
            }
        }
    }

    // MARK: - Profil Scrollvy
    private var profileScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 1. Gamer Card (Avatar, Namn, Bio, Spel-DNA badge & Redigera)
                gamerCardSection

                // 2. Spel-DNA Hero-sektion med insiktsrutor
                SpelDNACard(profile: computedSpelDNA) {
                    dismiss()
                }

                // 3. Mina favoritspel (Hylla)
                FavoriteGamesSection()

                // 4. GOTY Hall of Fame
                gotyHallOfFameSection

                // 5. Min Setup & Spelpreferenser (Kompakt sammanfattning med Redigera-knapp)
                preferencesSummarySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 75)
        }
        .refreshable {
            await profile.syncWithRemote()
            await store.syncWithRemote()
        }
        .task {
            await profile.syncWithRemote()
        }
    }

    // MARK: - 1. Gamer Card (Personlig presentation i toppen)
    private var gamerCardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                // Avatar (klickbar för att byta foto/avatar)
                Button {
                    showingAvatarPicker = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        UserAvatarView(size: 64)
                            .shadow(color: .black.opacity(0.35), radius: 5, y: 2)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4.5)
                            .background(Color.red, in: Circle())
                            .offset(x: 2, y: 2)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(profile.username.isEmpty ? "Spelare" : profile.username)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("\(profile.age) år")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    if !profile.gamerBio.isEmpty {
                        Text("\"\(profile.gamerBio)\"")
                            .font(.system(size: 12.5, weight: .medium))
                            .italic()
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    // Spel-DNA märke (om beräknat)
                    if let dna = computedSpelDNA {
                        HStack(spacing: 5) {
                            Text(dna.icon)
                                .font(.system(size: 11))
                            Text(dna.title)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(dna.accentColor)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(dna.accentColor.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(dna.accentColor.opacity(0.35), lineWidth: 0.8))
                        .padding(.top, 2)
                    }
                }

                Spacer()
            }

            // Snabbåtgärder under profilen (Redigera profil, Byt profil, Konto)
            HStack(spacing: 8) {
                Button {
                    tempUsername = profile.username
                    tempAgeString = "\(profile.age)"
                    tempGamerBio = profile.gamerBio
                    isEditingIdentity = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text("Redigera profil")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                }
                .buttonStyle(.plain)

                Button {
                    showingProfileSwitcher = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("Byt profil")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showingAccountSyncSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 10))
                        Text("Synk")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.ds.brandRed.opacity(0.15))
                    .foregroundStyle(Color.ds.brandRed)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Humör-indikator ("Just nu sugen på")
            Menu {
                ForEach(playingMoodOptions, id: \.self) { mood in
                    Button {
                        withAnimation {
                            profile.playingMood = mood
                        }
                    } label: {
                        HStack {
                            Text(mood)
                            if profile.playingMood == mood {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.red)
                    Text("Just nu sugen på:")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(profile.playingMood.isEmpty ? "Välj humör..." : profile.playingMood)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)

            // 🏆 GOTY & Spelåret Wrapped Banner (dyker upp i början av december varje år)
            if ProfileStore.isGotySeason {
                Button {
                    showingWrappedSheet = true
                } label: {
                    let currentYear = Calendar.current.component(.year, from: Date())
                    let crowned = profile.getGoty(forYear: currentYear).flatMap { id in store.games.first { $0.id == id } }

                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.orange.opacity(0.18))
                                .frame(width: 42, height: 42)
                            Text("👑")
                                .font(.system(size: 20))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text("SPELÅRET \(currentYear)")
                                    .font(.system(size: 9.5, weight: .black))
                                    .foregroundStyle(.orange)
                                    .tracking(1)

                                if crowned != nil {
                                    Text("GOTY KORAT")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 4.5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.yellow, in: Capsule())
                                }
                            }

                            Text(crowned != nil ? "Ditt GOTY: \(crowned!.title)" : "Kora ditt Game of the Year!")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text("Se din personliga årsstatistik & sammanfattning")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }



    // MARK: - 🏆 GOTY Hall of Fame Sektion
    private var gotyHallOfFameSection: some View {
        let sortedYears = profile.gotyByYear.keys.compactMap { Int($0) }.sorted(by: >)
        let crownedEntries: [(year: Int, game: Game)] = sortedYears.compactMap { year in
            if let uuid = profile.getGoty(forYear: year), let game = store.games.first(where: { $0.id == uuid }) {
                return (year: year, game: game)
            }
            return nil
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("👑")
                        .font(.subheadline)
                    Text("Mina Game of the Year")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                if !crownedEntries.isEmpty {
                    Text("(\(crownedEntries.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    wrappedSelectedYear = nil
                    showingWrappedSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Spelåret Wrapped")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.orange)
                }
                .buttonStyle(.plain)
            }

            if crownedEntries.isEmpty {
                // Inbjudande tomt läge
                Button {
                    wrappedSelectedYear = nil
                    showingWrappedSheet = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                            Text("🏆")
                                .font(.system(size: 24))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Din GOTY Hall of Fame")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                            Text("Kora dina favoritspel genom tiderna så samlas och firas de här år för år.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.orange.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                // Horisontell karusell med krönta spel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(crownedEntries, id: \.year) { item in
                            Button {
                                wrappedSelectedYear = item.year
                                showingWrappedSheet = true
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        CoverView(title: item.game.title, url: item.game.coverURL, corner: 14, height: 155)
                                            .frame(width: 105, height: 155)
                                            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                                            )

                                        // Årsbadge & Krona
                                        HStack(spacing: 3) {
                                            Text("👑")
                                                .font(.system(size: 9))
                                            Text(String(item.year))
                                                .font(.system(size: 10.5, weight: .black))
                                                .foregroundStyle(.black)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.yellow, in: Capsule())
                                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                                        .padding(6)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.game.title)
                                            .font(.system(size: 11.5, weight: .bold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                            .frame(width: 105, alignment: .leading)

                                        Text("Årets spel \(String(item.year))")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

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

    // MARK: - 5. Min Setup & Spelpreferenser (Kompakt sammanfattning med Redigera-knapp)
    private var preferencesSummarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Text("🎮")
                        .font(.subheadline)
                    Text("Min setup & preferenser")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button {
                    showingPreferencesSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .bold))
                        Text("Ändra")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.12), in: Capsule())
                    .foregroundStyle(Color.red)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 14) {
                // Aktuellt Spelhumör / Vibe (om satt)
                if !profile.playingMood.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.teal)
                        Text("Aktuell vibe:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(profile.playingMood)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.teal.opacity(0.25), lineWidth: 1))
                }

                // Plattformar / Setup
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 4) {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 10, weight: .bold))
                        Text("AKTIVA PLATTFORMAR")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                    if profile.platforms.isEmpty {
                        Text("Inga valda konsoler ännu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 7) {
                            ForEach(Array(profile.platforms).sorted(), id: \.self) { plat in
                                HStack(spacing: 5) {
                                    Image(systemName: platformIcon(for: plat))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color.blue)
                                    Text(plat)
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5.5)
                                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 1)

                // Favoritgenrer
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("FAVORITGENRER")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                    if profile.favoriteGenres.isEmpty {
                        Text("Inga genrer valda ännu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 7) {
                            ForEach(Array(profile.favoriteGenres).sorted(), id: \.self) { genre in
                                Text(genre)
                                    .font(.system(size: 11.5, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.red.opacity(0.12), in: Capsule())
                                    .foregroundStyle(Color.red)
                                    .overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 0.8))
                            }
                        }
                    }
                }

                // Spelstil (om valda)
                if !profile.playstyle.isEmpty {
                    Divider()
                        .padding(.vertical, 1)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("SPELSTIL")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                        FlowLayout(spacing: 7) {
                            ForEach(Array(profile.playstyle).sorted(), id: \.self) { style in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 7, weight: .black))
                                        .foregroundStyle(Color.orange)
                                    Text(style)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.orange)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4.5)
                                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.orange.opacity(0.3), lineWidth: 0.8))
                            }
                        }
                    }
                }

                // Spelmotiv (om valda)
                if !profile.playFor.isEmpty {
                    Divider()
                        .padding(.vertical, 1)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 9, weight: .bold))
                            Text("MOTIVATION & DRIVKRAFTER")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                        FlowLayout(spacing: 7) {
                            ForEach(Array(profile.playFor).sorted(), id: \.self) { motive in
                                Text(motive)
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4.5)
                                    .background(Color.purple.opacity(0.12), in: Capsule())
                                    .foregroundStyle(Color.purple)
                                    .overlay(Capsule().stroke(Color.purple.opacity(0.3), lineWidth: 0.8))
                            }
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Redigera identitet Sheet
    private var editIdentitySheet: some View {
        NavigationStack {
            Form {
                Section("Spelarnamn") {
                    TextField("Ditt namn", text: $tempUsername)
                        .autocorrectionDisabled()
                }

                Section("Ålder") {
                    TextField("Ålder", text: $tempAgeString)
                        .keyboardType(.numberPad)
                }

                Section("Spelar-motto / Bio") {
                    TextField("Kort motto eller gaming-citat", text: $tempGamerBio)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Redigera profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        isEditingIdentity = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        let trimmed = tempUsername.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            profile.username = trimmed
                        }
                        if let ageNum = Int(tempAgeString), ageNum > 0 && ageNum < 120 {
                            profile.age = ageNum
                        }
                        profile.gamerBio = tempGamerBio.trimmingCharacters(in: .whitespacesAndNewlines)
                        isEditingIdentity = false
                    }
                    .bold()
                    .foregroundStyle(Color.red)
                }
            }
        }
        .presentationDetents([.fraction(0.55), .medium])
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
