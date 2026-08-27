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
    var platformID: Int? = nil
    var platformName: String? = nil
    var genre: String? = nil
    var developer: String = ""
    var sortOption: DiscoverSortOption = .popularity

    var isActive: Bool {
        startYear != nil || endYear != nil || platformID != nil || genre != nil || !developer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sortOption != .popularity
    }

    var activeFilterCount: Int {
        var count = 0
        if startYear != nil || endYear != nil { count += 1 }
        if platformID != nil { count += 1 }
        if genre != nil { count += 1 }
        if !developer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if sortOption != .popularity { count += 1 }
        return count
    }

    mutating func reset() {
        startYear = nil
        endYear = nil
        platformID = nil
        platformName = nil
        genre = nil
        developer = ""
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

struct AdvancedSearchFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
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
                Section("Plattform") {
                    Picker("Välj plattform", selection: $localConfig.platformID) {
                        Text("Alla plattformar").tag(nil as Int?)
                        ForEach(availablePlatforms) { plat in
                            Text(plat.name).tag(plat.id as Int?)
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
                Section("Genre") {
                    Picker("Välj genre", selection: $localConfig.genre) {
                        Text("Alla genrer").tag(nil as String?)
                        ForEach(availableGenres, id: \.queryName) { g in
                            Text(g.name).tag(g.queryName as String?)
                        }
                    }
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
