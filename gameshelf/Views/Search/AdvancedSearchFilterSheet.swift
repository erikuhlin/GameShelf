//
//  AdvancedSearchFilterSheet.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-15.
//

import SwiftUI

struct SearchFilterConfig: Equatable {
    var startYear: Int? = nil
    var endYear: Int? = nil
    var platformIDs: Set<Int> = []
    var genres: Set<String> = []
    var developer: String = ""
    var minRating: Int = 0
    var hideOwned: Bool = false
    var sortOption: DiscoverSortOption = .popularity

    init(
        startYear: Int? = nil,
        endYear: Int? = nil,
        platformIDs: Set<Int> = [],
        genres: Set<String> = [],
        developer: String = "",
        minRating: Int = 0,
        hideOwned: Bool = false,
        sortOption: DiscoverSortOption = .popularity
    ) {
        self.startYear = startYear
        self.endYear = endYear
        self.platformIDs = platformIDs
        self.genres = genres
        self.developer = developer
        self.minRating = minRating
        self.hideOwned = hideOwned
        self.sortOption = sortOption
    }

    // Bakåtkompatibilitet
    var platformID: Int? {
        get { platformIDs.first }
        set {
            if let val = newValue { platformIDs = [val] }
            else { platformIDs.removeAll() }
        }
    }
    var genre: String? {
        get { genres.first }
        set {
            if let val = newValue { genres = [val] }
            else { genres.removeAll() }
        }
    }

    var isActive: Bool {
        startYear != nil || endYear != nil || !platformIDs.isEmpty || !genres.isEmpty || !developer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sortOption != .popularity || minRating > 0 || hideOwned
    }

    var activeFilterCount: Int {
        var count = 0
        if startYear != nil || endYear != nil { count += 1 }
        count += platformIDs.count
        count += genres.count
        if !developer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if sortOption != .popularity { count += 1 }
        if minRating > 0 { count += 1 }
        if hideOwned { count += 1 }
        return count
    }

    mutating func reset() {
        startYear = nil
        endYear = nil
        platformIDs.removeAll()
        genres.removeAll()
        developer = ""
        minRating = 0
        hideOwned = false
        sortOption = .popularity
    }
}

enum QuickPeriod: String, CaseIterable, Identifiable {
    case all = "Alla år"
    case latest = "2024–2026"
    case early2020s = "2020–2023"
    case late2010s = "2015–2019"
    case early2010s = "2011–2014"
    case decade2000s = "2000–2009"
    case decade90s = "90-talet"
    case custom = "Anpassat"

    var id: String { rawValue }

    var range: (start: Int?, end: Int?) {
        switch self {
        case .all: return (nil, nil)
        case .latest: return (2024, 2026)
        case .early2020s: return (2020, 2023)
        case .late2010s: return (2015, 2019)
        case .early2010s: return (2011, 2014)
        case .decade2000s: return (2000, 2009)
        case .decade90s: return (1990, 1999)
        case .custom: return (nil, nil)
        }
    }
}

struct PlatformOption: Identifiable {
    let id: Int
    let name: String
    let icon: String
}

enum SmartSearchPreset: String, CaseIterable, Identifiable {
    case trending = "Hetaste just nu 🔥"
    case masterpieces = "Mästerverk (90+) ⭐"
    case retro2000s = "2000-talets Nostalgi ⏳"
    case hidden = "Dolda Pärlor 💎"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .trending: return "Nyutgivna titlar med högst hype"
        case .masterpieces: return "Topprankade spel med 90+ betyg"
        case .retro2000s: return "Guldåldersspel från 2000–2006"
        case .hidden: return "Högt betyg, låg uppmärksamhet"
        }
    }

    var config: SearchFilterConfig {
        switch self {
        case .trending:
            return SearchFilterConfig(sortOption: .releaseDateDesc)
        case .masterpieces:
            return SearchFilterConfig(minRating: 90, sortOption: .rating)
        case .retro2000s:
            return SearchFilterConfig(startYear: 2000, endYear: 2006, minRating: 75, sortOption: .rating)
        case .hidden:
            return SearchFilterConfig(minRating: 82, sortOption: .rating)
        }
    }
}

struct AdvancedSearchFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profile: ProfileStore
    @Binding var config: SearchFilterConfig
    var onApply: () -> Void

    @State private var localConfig: SearchFilterConfig
    @State private var selectedPeriod: QuickPeriod = .all
    @State private var customStartYear: Int = 2011
    @State private var customEndYear: Int = 2014

    private let availablePlatforms: [PlatformOption] = [
        PlatformOption(id: 167, name: "PlayStation 5", icon: "playstation.logo"),
        PlatformOption(id: 48, name: "PlayStation 4", icon: "playstation.logo"),
        PlatformOption(id: 9, name: "PlayStation 3", icon: "playstation.logo"),
        PlatformOption(id: 169, name: "Xbox Series X/S", icon: "xbox.logo"),
        PlatformOption(id: 49, name: "Xbox One", icon: "xbox.logo"),
        PlatformOption(id: 12, name: "Xbox 360", icon: "xbox.logo"),
        PlatformOption(id: 130, name: "Nintendo Switch", icon: "gamecontroller"),
        PlatformOption(id: 6, name: "PC (Windows)", icon: "desktopcomputer")
    ]

    private let popularDevelopers: [String] = [
        "FromSoftware", "Rockstar Games", "Naughty Dog", "Capcom",
        "Nintendo", "CD Projekt Red", "Bethesda", "Square Enix",
        "Bungie", "BioWare", "Valve", "Ubisoft", "EA", "Remedy"
    ]

    private let availableGenres: [(name: String, queryName: String)] = [
        ("RPG", "Role-playing (RPG)"),
        ("Action", "Action"),
        ("Skjutspel", "Shooter"),
        ("Äventyr", "Adventure"),
        ("Strategi", "Strategy"),
        ("Skräck", "Horror"),
        ("Racing", "Racing"),
        ("Plattform", "Platform"),
        ("Simulator", "Simulator"),
        ("Sport", "Sport"),
        ("Pussel", "Puzzle"),
        ("Fighting", "Fighting"),
        ("Indie", "Indie")
    ]

    init(config: Binding<SearchFilterConfig>, onApply: @escaping () -> Void) {
        self._config = config
        self.onApply = onApply
        self._localConfig = State(initialValue: config.wrappedValue)

        // Identifiera initial QuickPeriod
        let s = config.wrappedValue.startYear
        let e = config.wrappedValue.endYear
        if s == nil && e == nil {
            _selectedPeriod = State(initialValue: .all)
        } else if s == 2024 && e == 2026 {
            _selectedPeriod = State(initialValue: .latest)
        } else if s == 2020 && e == 2023 {
            _selectedPeriod = State(initialValue: .early2020s)
        } else if s == 2015 && e == 2019 {
            _selectedPeriod = State(initialValue: .late2010s)
        } else if s == 2011 && e == 2014 {
            _selectedPeriod = State(initialValue: .early2010s)
        } else if s == 2000 && e == 2009 {
            _selectedPeriod = State(initialValue: .decade2000s)
        } else if s == 1990 && e == 1999 {
            _selectedPeriod = State(initialValue: .decade90s)
        } else {
            _selectedPeriod = State(initialValue: .custom)
            if let s = s { _customStartYear = State(initialValue: s) }
            if let e = e { _customEndYear = State(initialValue: e) }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // 1. Sortering
                Section("Sortering") {
                    Picker("Sortera efter", selection: $localConfig.sortOption) {
                        ForEach(DiscoverSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 2. Tidsperiod / Årtal
                Section("Tidsperiod & Årtal") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(QuickPeriod.allCases) { period in
                                let isSelected = selectedPeriod == period
                                Button {
                                    withAnimation {
                                        selectedPeriod = period
                                        if period != .custom {
                                            localConfig.startYear = period.range.start
                                            localConfig.endYear = period.range.end
                                        } else {
                                            localConfig.startYear = customStartYear
                                            localConfig.endYear = customEndYear
                                        }
                                    }
                                } label: {
                                    Text(period.rawValue)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(isSelected ? Color.red : Color(.tertiarySystemFill))
                                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if selectedPeriod == .custom {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Från år:")
                                    .font(.subheadline)
                                Spacer()
                                Picker("Från år", selection: $customStartYear) {
                                    ForEach((1980...2026).reversed(), id: \.self) { yr in
                                        Text("\(String(yr))").tag(yr)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            HStack {
                                Text("Till år:")
                                    .font(.subheadline)
                                Spacer()
                                Picker("Till år", selection: $customEndYear) {
                                    ForEach((1980...2026).reversed(), id: \.self) { yr in
                                        Text("\(String(yr))").tag(yr)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .onChange(of: customStartYear) { _, newVal in
                            if newVal > customEndYear { customEndYear = newVal }
                            localConfig.startYear = customStartYear
                            localConfig.endYear = customEndYear
                        }
                        .onChange(of: customEndYear) { _, newVal in
                            if newVal < customStartYear { customStartYear = newVal }
                            localConfig.startYear = customStartYear
                            localConfig.endYear = customEndYear
                        }
                    }
                }

                // 3. Plattform
                Section {
                    if !profile.platforms.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(profile.platforms), id: \.self) { platName in
                                    if let match = availablePlatforms.first(where: { platName.localizedCaseInsensitiveContains($0.name) || $0.name.localizedCaseInsensitiveContains(platName) }) {
                                        let isSelected = localConfig.platformIDs.contains(match.id)
                                        Button {
                                            withAnimation(.snappy(duration: 0.2)) {
                                                if isSelected {
                                                    localConfig.platformIDs.remove(match.id)
                                                } else {
                                                    localConfig.platformIDs.insert(match.id)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: isSelected ? "checkmark.circle.fill" : "gamecontroller.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(isSelected ? Color.white : Color.blue)
                                                Text(match.name)
                                                    .font(.caption2.weight(.semibold))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availablePlatforms) { plat in
                                let isSelected = localConfig.platformIDs.contains(plat.id)
                                Button {
                                    withAnimation(.snappy(duration: 0.2)) {
                                        if isSelected {
                                            localConfig.platformIDs.remove(plat.id)
                                        } else {
                                            localConfig.platformIDs.insert(plat.id)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        Text(plat.name)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    HStack {
                        Text("Plattform")
                        if !localConfig.platformIDs.isEmpty {
                            Spacer()
                            Text("\(localConfig.platformIDs.count) valda")
                                .font(.caption2.bold())
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // 4. Utvecklare / Studio
                Section("Utvecklare / Studio") {
                    HStack {
                        Image(systemName: "building.2.crop.circle")
                            .foregroundStyle(.secondary)
                        TextField("T.ex. FromSoftware, Rockstar...", text: $localConfig.developer)
                            .textFieldStyle(.plain)
                        if !localConfig.developer.isEmpty {
                            Button {
                                localConfig.developer = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(popularDevelopers, id: \.self) { dev in
                                let isSelected = localConfig.developer.lowercased() == dev.lowercased()
                                Button {
                                    withAnimation {
                                        if isSelected {
                                            localConfig.developer = ""
                                        } else {
                                            localConfig.developer = dev
                                        }
                                    }
                                } label: {
                                    Text(dev)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.red : Color(.tertiarySystemFill))
                                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // 5. Genre
                Section {
                    if !profile.favoriteGenres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(profile.favoriteGenres), id: \.self) { favGenre in
                                    let match = availableGenres.first(where: {
                                        $0.name.localizedCaseInsensitiveContains(favGenre) ||
                                        favGenre.localizedCaseInsensitiveContains($0.name) ||
                                        $0.queryName.localizedCaseInsensitiveContains(favGenre)
                                    })
                                    let queryVal = match?.queryName ?? favGenre
                                    let isSelected = localConfig.genres.contains(queryVal)

                                    Button {
                                        withAnimation(.snappy(duration: 0.2)) {
                                            if isSelected {
                                                localConfig.genres.remove(queryVal)
                                            } else {
                                                localConfig.genres.insert(queryVal)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 8))
                                                .foregroundStyle(isSelected ? Color.white : Color.red)
                                            Text(favGenre)
                                                .font(.caption2.weight(.semibold))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.red : Color(.tertiarySystemFill))
                                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableGenres, id: \.queryName) { g in
                                let isSelected = localConfig.genres.contains(g.queryName)
                                Button {
                                    withAnimation(.snappy(duration: 0.2)) {
                                        if isSelected {
                                            localConfig.genres.remove(g.queryName)
                                        } else {
                                            localConfig.genres.insert(g.queryName)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        Text(g.name)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Color.red : Color(.tertiarySystemFill))
                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    HStack {
                        Text("Genre")
                        if !localConfig.genres.isEmpty {
                            Spacer()
                            Text("\(localConfig.genres.count) valda")
                                .font(.caption2.bold())
                                .foregroundStyle(.red)
                        }
                    }
                }

                // 6. Minsta betyg
                Section("Minsta betyg") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([
                                (label: "Alla", value: 0),
                                (label: "70+", value: 70),
                                (label: "80+", value: 80),
                                (label: "85+", value: 85),
                                (label: "90+ 🏆", value: 90)
                            ], id: \.value) { option in
                                let isSelected = localConfig.minRating == option.value
                                Button {
                                    withAnimation { localConfig.minRating = option.value }
                                } label: {
                                    Text(option.label)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(isSelected ? Color.red : Color(.tertiarySystemFill))
                                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // 7. Dölj ägda spel
                Section {
                    Toggle("Dölj spel jag äger", isOn: $localConfig.hideOwned)
                        .tint(.red)
                }

                // Nollställ
                if localConfig.isActive {
                    Section {
                        Button(role: .destructive) {
                            withAnimation {
                                localConfig.reset()
                                selectedPeriod = .all
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Nollställ alla filter")
                                    .font(.subheadline.bold())
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filtrera sökning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") {
                        config = localConfig
                        onApply()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(.red)
                }
            }
        }
    }
}
