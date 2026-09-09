//
//  ProfileView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-08.
//

import SwiftUI

enum ProfileTab: String, CaseIterable, Identifiable {
    case profile = "Profil & DNA"
    case activity = "Aktivitet & Statistik"

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
    @State private var showingAvatarPicker = false
    @State private var isEditingIdentity = false
    @State private var tempUsername = ""
    @State private var tempAgeString = ""

    @State private var tempGamerBio = ""

    // Utökade plattformar för "Min setup"
    private let availablePlatforms = [
        "PlayStation 5",
        "Xbox Series X",
        "PC",
        "Nintendo Switch",
        "Steam Deck",
        "PlayStation 4",
        "Xbox One",
        "Retro / Övrigt"
    ]

    // Utökade standardgenrer för "Mina spelpreferenser"
    private let genreOptions = [
        "RPG",
        "Action",
        "Soulslike",
        "Skräck",
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
        "Cozy",
        "Hack & Slash",
        "Smygspel",
        "Berättelsedrivet",
        "MMO"
    ]

    // Utökade spelmotiv
    private let playForOptions = [
        "Story",
        "Utforskning",
        "Action",
        "Tävling",
        "Avkoppling",
        "Utmaning",
        "Kreativitet",
        "Samarbete & Gemenskap",
        "Djup Lore & Världsbygge",
        "Nostalgi & Retro",
        "100% Completionism",
        "Snabba sessioner",
        "Adrenalin & Puls",
        "Taktik & Problemlösning"
    ]

    // Min Spelstil
    private let playstyleOptions = [
        "Singleplayer",
        "Co-op / Samarbete",
        "PvP / Multiplayer",
        "Trophy Hunter",
        "Casual / Avslappnad"
    ]

    // Aktuellt spelhumör
    private let playingMoodOptions = [
        "Utforska nya världar",
        "Mysigt & Avkopplande",
        "Brutal bossutmaning",
        "Djup story & lore",
        "Snabba matcher & action",
        "Klurig taktik & hjärngympa"
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
            .sheet(isPresented: $showingSettingsSheet) {
                ProfileSettingsSheet()
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingAvatarPicker) {
                AvatarPickerSheet()
                    .environmentObject(profile)
            }
            .sheet(isPresented: $isEditingIdentity) {
                editIdentitySheet
            }
        }
    }

    // MARK: - Profil Scrollvy
    private var profileScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 1. Identitet
                identitySection

                // 2. Spel-DNA Hero-sektion (10 arketyper)
                SpelDNACard(profile: computedSpelDNA) {
                    // CTA till bibliotek
                    dismiss()
                }

                // 3. Min setup
                setupSection

                // 4. Mina spelpreferenser
                preferencesSection

                // 5. Mina favoritspel
                FavoriteGamesSection()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
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

    // MARK: - 1. Identitet
    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                // Avatar (klickbar för att välja avatar eller foto)
                Button {
                    showingAvatarPicker = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        UserAvatarView(size: 58)
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.red, in: Circle())
                            .offset(x: 2, y: 2)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(profile.username.isEmpty ? "Spelare" : profile.username)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.primary)

                        Button {
                            tempUsername = profile.username
                            tempAgeString = "\(profile.age)"
                            tempGamerBio = profile.gamerBio
                            isEditingIdentity = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("\(profile.age) år")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    if !profile.gamerBio.isEmpty {
                        Text("\"\(profile.gamerBio)\"")
                            .font(.system(size: 12, weight: .medium))
                            .italic()
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.top, 1)
                    }

                    // Snabbknappar för Byt profil och Koppla enheter
                    HStack(spacing: 8) {
                        Button {
                            showingProfileSwitcher = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 10))
                                Text("Byt profil")
                                    .font(.caption2.bold())
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingPairingSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10))
                                Text("Koppla enhet")
                                    .font(.caption2.bold())
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.ds.brandRed.opacity(0.15))
                            .foregroundStyle(Color.ds.brandRed)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 3)
                }

                Spacer()
            }

            // Humör-indikator
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
                    Text(profile.playingMood)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 3. Min setup
    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("🎮")
                    .font(.subheadline)
                Text("Min setup")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text("Plattformar")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)

            // Plattformschips
            FlowLayout(spacing: 8) {
                ForEach(availablePlatforms, id: \.self) { plat in
                    let isSelected = profile.platforms.contains(plat)
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            profile.toggle(plat)
                        }
                    } label: {
                        HStack(spacing: 7) {
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
                        .padding(.vertical, 9)
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
    }

    // MARK: - 4. Mina spelpreferenser
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                Text("❤️")
                    .font(.subheadline)
                Text("Mina spelpreferenser")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            // Block 1: Min Spelstil
            VStack(alignment: .leading, spacing: 9) {
                Text("Min spelstil")
                    .font(.system(size: 12.5, weight: .semibold))
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

            // Block 2: Favoritgenrer
            VStack(alignment: .leading, spacing: 9) {
                Text("Favoritgenrer")
                    .font(.system(size: 12.5, weight: .semibold))
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

            // Block 3: Jag spelar helst för
            VStack(alignment: .leading, spacing: 9) {
                Text("Jag spelar helst för")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)

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
