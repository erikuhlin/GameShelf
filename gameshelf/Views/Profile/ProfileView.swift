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
    @State private var showingAvatarPicker = false
    @State private var isEditingIdentity = false
    @State private var tempUsername = ""
    @State private var tempAgeString = ""

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
        "Skräck",
        "FPS",
        "Äventyr",
        "Strategi",
        "Simulator",
        "Plattform",
        "Pussel",
        "Sport",
        "Racing",
        "Fighting",
        "Indie",
        "Cozy"
    ]

    // Utökade spelmotiv
    private let playForOptions = [
        "Story",
        "Utforskning",
        "Action",
        "Tävling",
        "Avkoppling",
        "Utmaning",
        "Kreativitet"
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
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .padding(.bottom, 40)
        }
    }

    // MARK: - 1. Identitet
    private var identitySection: some View {
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

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.username.isEmpty ? "Spelare" : profile.username)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)

                    Button {
                        tempUsername = profile.username
                        tempAgeString = "\(profile.age)"
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
            }

            Spacer()
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Text("❤️")
                    .font(.subheadline)
                Text("Mina spelpreferenser")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            // Block 1: Favoritgenrer
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

            // Block 2: Jag spelar helst för
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
                        isEditingIdentity = false
                    }
                    .bold()
                    .foregroundStyle(Color.red)
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium])
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
