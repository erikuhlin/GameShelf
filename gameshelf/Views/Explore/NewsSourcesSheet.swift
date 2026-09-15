//
//  NewsSourcesSheet.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-09-15.
//

import SwiftUI

struct NewsSourcesSheet: View {
    @ObservedObject var news: NewsFetcher
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSources: Set<String> = []
    @State private var searchText = ""

    struct SourceCategory: Identifiable {
        let id: String
        let title: String
        let icon: String
        let sources: [String]
    }

    private let categories: [SourceCategory] = [
        SourceCategory(
            id: "swedish",
            title: "Svenska spelmedier",
            icon: "🇸🇪",
            sources: ["FZ.se", "Gamereactor SE"]
        ),
        SourceCategory(
            id: "official",
            title: "Officiella bloggar",
            icon: "🏛️",
            sources: ["PlayStation Blog", "Xbox Wire"]
        ),
        SourceCategory(
            id: "major",
            title: "Stora globala medier",
            icon: "🌟",
            sources: [
                "Game Informer",
                "IGN",
                "Eurogamer",
                "GameSpot",
                "Polygon",
                "Kotaku",
                "VGC",
                "GamesRadar+",
                "VG247",
                "Destructoid"
            ]
        ),
        SourceCategory(
            id: "platform",
            title: "Plattform & Format",
            icon: "🎮",
            sources: [
                "Push Square",
                "Nintendo Life",
                "Pure Xbox",
                "PC Gamer",
                "Rock Paper Shotgun",
                "PCGamesN",
                "Nintendo Everything"
            ]
        ),
        SourceCategory(
            id: "niche",
            title: "Nisch & Japanskt",
            icon: "🗾",
            sources: ["Gematsu", "Siliconera", "TouchArcade"]
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                // Snabbalternativ
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Anpassa vilka källor som ska visas i ditt nyhetsflöde. Ändringar sparas automatiskt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Button {
                                selectAll()
                            } label: {
                                Label("Välj alla", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)

                            Button {
                                selectSwedishOnly()
                            } label: {
                                Text("🇸🇪 Endast svenska")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)

                            Button {
                                selectMajorOnly()
                            } label: {
                                Label("Största", systemImage: "sparkles")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Grupperade källor
                ForEach(visibleCategories) { category in
                    Section {
                        ForEach(category.sources, id: \.self) { source in
                            let isSelected = selectedSources.contains(source)
                            Button {
                                toggle(source: source)
                            } label: {
                                HStack {
                                    Text(source)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.red)
                                            .font(.body.weight(.semibold))
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                            .font(.body)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text("\(category.icon) \(category.title)")
                            Spacer()
                            Button(allSelected(in: category) ? "Avmarkera" : "Markera alla") {
                                toggleCategory(category)
                            }
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Sök bland källor...")
            .navigationTitle("Anpassa källor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") {
                        saveAndDismiss()
                    }
                    .font(.body.bold())
                    .tint(.red)
                }
            }
            .onAppear {
                let current = news.enabledSources
                if current.isEmpty {
                    selectedSources = Set(news.allAvailableSources)
                } else {
                    selectedSources = current
                }
            }
        }
    }

    private var visibleCategories: [SourceCategory] {
        let all = news.allAvailableSources
        var assigned = Set<String>()

        var result: [SourceCategory] = []
        for cat in categories {
            let available = cat.sources.filter { all.contains($0) }
            let filtered = searchText.isEmpty
                ? available
                : available.filter { $0.localizedCaseInsensitiveContains(searchText) }
            if !filtered.isEmpty {
                available.forEach { assigned.insert($0) }
                result.append(SourceCategory(id: cat.id, title: cat.title, icon: cat.icon, sources: filtered))
            }
        }

        let leftover = all.filter { !assigned.contains($0) }
        let filteredLeftover = searchText.isEmpty
            ? leftover
            : leftover.filter { $0.localizedCaseInsensitiveContains(searchText) }
        if !filteredLeftover.isEmpty {
            result.append(SourceCategory(id: "other", title: "Övriga källor", icon: "📰", sources: filteredLeftover))
        }

        return result
    }

    private func toggle(source: String) {
        if selectedSources.contains(source) {
            if selectedSources.count > 1 {
                selectedSources.remove(source)
            }
        } else {
            selectedSources.insert(source)
        }
    }

    private func allSelected(in category: SourceCategory) -> Bool {
        category.sources.allSatisfy { selectedSources.contains($0) }
    }

    private func toggleCategory(_ category: SourceCategory) {
        if allSelected(in: category) {
            let toRemove = Set(category.sources)
            let remainder = selectedSources.subtracting(toRemove)
            if !remainder.isEmpty {
                selectedSources = remainder
            }
        } else {
            selectedSources.formUnion(category.sources)
        }
    }

    private func selectAll() {
        selectedSources = Set(news.allAvailableSources)
    }

    private func selectSwedishOnly() {
        let swedish = news.allAvailableSources.filter { ["FZ.se", "Gamereactor SE"].contains($0) }
        if !swedish.isEmpty {
            selectedSources = Set(swedish)
        }
    }

    private func selectMajorOnly() {
        let major = news.allAvailableSources.filter {
            ["FZ.se", "Gamereactor SE", "Game Informer", "IGN", "Eurogamer", "PlayStation Blog", "Xbox Wire"].contains($0)
        }
        if !major.isEmpty {
            selectedSources = Set(major)
        }
    }

    private func saveAndDismiss() {
        news.updateEnabledSources(selectedSources)
        dismiss()
    }
}
