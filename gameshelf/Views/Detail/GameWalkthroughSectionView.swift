//
//  GameWalkthroughSectionView.swift
//  gameshelf
//
//  Created by Antigravity on 2026-10-24.
//

import SwiftUI

struct GameWalkthroughSectionView: View {
    let game: Game
    let remoteIGDBID: Int?
    let onUpdateGame: (Game) -> Void

    @AppStorage("gemini_api_key") private var geminiApiKey: String = ""

    @State private var isCheckingSupabase = false
    @State private var hasCheckedSupabase = false
    @State private var isGeneratingAI = false
    @State private var aiErrorMessage: String? = nil

    // Spoiler & Act collapse state
    @State private var unlockedActNames: Set<String> = []
    @State private var collapsedActNames: Set<String> = []
    @State private var showAllActsSpoilerFree = false
    @State private var isExpandedView = false

    // Redigeringsläge
    @State private var isEditingWalkthrough = false
    @State private var newStepTitle = ""
    @State private var newStepGroup = ""
    @State private var showingManualImportSheet = false
    @State private var manualImportText = ""
    @State private var showingAPIKeyPrompt = false
    @State private var apiKeyDraft = ""

    private var walkthroughItems: [GameTodoItem] {
        let items = game.todos.filter { $0.chapterGroup != nil || $0.order != nil }
        return items.sorted { ($0.order ?? 9999) < ($1.order ?? 9999) }
    }

    private var personalTodoItems: [GameTodoItem] {
        game.todos.filter { $0.chapterGroup == nil && $0.order == nil }
    }

    private struct ActSection: Identifiable {
        var id: String { name }
        let name: String
        let index: Int
        let items: [GameTodoItem]

        var completedCount: Int {
            items.filter(\.isDone).count
        }

        var isCompleted: Bool {
            !items.isEmpty && completedCount == items.count
        }
    }

    private var actSections: [ActSection] {
        var order: [String] = []
        var dict: [String: [GameTodoItem]] = [:]

        for item in walkthroughItems {
            let group = (item.chapterGroup?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Huvudberättelsen"
            if dict[group] == nil {
                order.append(group)
                dict[group] = []
            }
            dict[group]?.append(item)
        }

        return order.enumerated().map { idx, name in
            ActSection(name: name, index: idx, items: dict[name] ?? [])
        }
    }

    /// Den akt där spelaren befinner sig just nu (första akten med minst ett oavklarat kapitel)
    private var activeActIndex: Int {
        if let idx = actSections.firstIndex(where: { !$0.isCompleted }) {
            return idx
        }
        return max(0, actSections.count - 1)
    }

    private var nextActiveStep: GameTodoItem? {
        walkthroughItems.first(where: { !$0.isDone })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 2)

            // Rubrikrad
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "list.Number")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Text("STORY & KAPITELLISTA")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                }

                Spacer()

                if !walkthroughItems.isEmpty {
                    let done = walkthroughItems.filter(\.isDone).count
                    let total = walkthroughItems.count
                    let pct = total > 0 ? Int(round((Double(done) / Double(total)) * 100)) : 0

                    Text("\(done)/\(total) (\(pct)%)")
                        .font(.caption.bold())
                        .foregroundStyle(done == total ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((done == total ? Color.green : Color.red).opacity(0.12), in: Capsule())
                }
            }

            if isCheckingSupabase && walkthroughItems.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Kontrollerar verifierad kapitellista...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } else if !walkthroughItems.isEmpty {
                loadedWalkthroughContent
            } else {
                emptyWalkthroughPrompt
            }

            if let err = aiErrorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .task(id: game.id) {
            await autoLoadWalkthroughIfNeeded()
        }
        .sheet(isPresented: $showingManualImportSheet) {
            manualImportSheetView
        }
        .alert("Ange Gemini API-nyckel", isPresented: $showingAPIKeyPrompt) {
            TextField("AIzaSy...", text: $apiKeyDraft)
            Button("Spara & Hämta") {
                let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    geminiApiKey = trimmed
                    Task { await generateWithGeminiAI() }
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("För att generera nya 1:1-kapitellistor med AI behövs en Gemini API-nyckel. Den sparas lokalt i appen.")
        }
    }

    // MARK: - Loaded Walkthrough View

    @ViewBuilder
    private var loadedWalkthroughContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Kompakt "Nästa steg"-kort så man snabbt kan bocka av utan att fälla ut hela listan
            if let next = nextActiveStep {
                HStack(spacing: 10) {
                    Button {
                        toggleStep(next)
                    } label: {
                        Image(systemName: "circle")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text("NÄSTA KAPITEL")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.red)
                                .tracking(0.5)
                            if let grp = next.chapterGroup, !grp.isEmpty {
                                Text("· \(grp)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Text(next.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            isExpandedView.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isExpandedView ? "Dölj" : "Alla kapitel")
                                .font(.caption.bold())
                            Image(systemName: isExpandedView ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                // Alla kapitel avklarade
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Alla \(walkthroughItems.count) kapitel avklarade!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button(isExpandedView ? "Dölj" : "Visa lista") {
                        withAnimation { isExpandedView.toggle() }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Utfälld akt-grupperad 1:1-lista med spoilerskydd på aktnivå
            if isExpandedView {
                VStack(alignment: .leading, spacing: 10) {
                    // Verktygsrad för spoilerskydd & redigering
                    HStack(spacing: 10) {
                        Button {
                            withAnimation {
                                showAllActsSpoilerFree.toggle()
                            }
                        } label: {
                            Label(
                                showAllActsSpoilerFree ? "Spoilerskydd: Av" : "Spoilerskydd: På",
                                systemImage: showAllActsSpoilerFree ? "eye.fill" : "eye.slash.fill"
                            )
                            .font(.caption2.bold())
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            withAnimation {
                                isEditingWalkthrough.toggle()
                            }
                        } label: {
                            Label(isEditingWalkthrough ? "Klar" : "Redigera", systemImage: isEditingWalkthrough ? "checkmark" : "pencil")
                                .font(.caption2.bold())
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(isEditingWalkthrough ? Color.red : Color(.tertiarySystemFill), in: Capsule())
                                .foregroundStyle(isEditingWalkthrough ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Akter
                    ForEach(actSections) { section in
                        actSectionView(section)
                    }

                    // Lägg till nytt kapitel i redigeringsläge
                    if isEditingWalkthrough {
                        addCustomWalkthroughStepRow
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func actSectionView(_ section: ActSection) -> some View {
        let isFutureLockedAct = section.index > activeActIndex && !showAllActsSpoilerFree && !unlockedActNames.contains(section.name) && !isEditingWalkthrough
        let isCollapsed = collapsedActNames.contains(section.name)

        VStack(alignment: .leading, spacing: 6) {
            // Akt-header
            HStack(spacing: 8) {
                Button {
                    if isFutureLockedAct {
                        withAnimation {
                            _ = unlockedActNames.insert(section.name)
                        }
                    } else {
                        withAnimation {
                            if isCollapsed {
                                collapsedActNames.remove(section.name)
                            } else {
                                _ = collapsedActNames.insert(section.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isFutureLockedAct ? "lock.fill" : (section.isCompleted ? "checkmark.circle.fill" : (isCollapsed ? "chevron.right" : "chevron.down")))
                            .font(.caption2.bold())
                            .foregroundStyle(isFutureLockedAct ? Color.secondary : (section.isCompleted ? Color.green : Color.red))

                        Text(isFutureLockedAct ? "Akt \(section.index + 1) (Spoilerskyddad)" : section.name)
                            .font(.caption.bold())
                            .foregroundStyle(isFutureLockedAct ? .secondary : .primary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(section.completedCount)/\(section.items.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isFutureLockedAct {
                    Button("Lås upp") {
                        withAnimation {
                            _ = unlockedActNames.insert(section.name)
                        }
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            // Kapitel i akten (visas om ej låst och ej ihopfälld)
            if !isFutureLockedAct && !isCollapsed {
                VStack(spacing: 4) {
                    ForEach(section.items) { item in
                        HStack(spacing: 10) {
                            Button {
                                toggleStep(item)
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.subheadline)
                                    .foregroundStyle(item.isDone ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            if let ord = item.order {
                                Text("\(ord).")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 22, alignment: .trailing)
                            }

                            Text(item.title)
                                .font(.caption)
                                .foregroundStyle(item.isDone ? .secondary : .primary)
                                .strikethrough(item.isDone, color: .secondary)
                                .lineLimit(2)

                            Spacer()

                            if isEditingWalkthrough {
                                Button(role: .destructive) {
                                    deleteStep(item)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill).opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.leading, 8)
            }
        }
    }

    private var addCustomWalkthroughStepRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lägg till eget kapitel")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField("Akt (valfritt)", text: $newStepGroup)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(width: 110)

                TextField("Kapitelnamn...", text: $newStepTitle)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    addCustomStep()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(newStepTitle.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .red)
                }
                .disabled(newStepTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Empty State (Hämta med AI eller Klistra in)

    private var emptyWalkthroughPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingen kapitellista laddad för detta spel ännu. Hämta en komplett 1:1-guide med AI (sparas till databasen) eller klistra in en egen lista.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    if geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        apiKeyDraft = ""
                        showingAPIKeyPrompt = true
                    } else {
                        Task { await generateWithGeminiAI() }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isGeneratingAI {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.caption.bold())
                        }
                        Text(isGeneratingAI ? "Skapar 1:1-guide..." : "Hämta med AI")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(isGeneratingAI)
                .buttonStyle(.plain)

                Button {
                    manualImportText = ""
                    showingManualImportSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption.bold())
                        Text("Klistra in")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.tertiarySystemFill))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var manualImportSheetView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Klistra in kapitel eller uppdrag (en per rad). Rader som börjar med '#' eller slutar med ':' tolkar appen som aktnamn.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $manualImportText)
                    .font(.subheadline)
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding(16)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Importera kapitellista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        showingManualImportSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        importManualLines()
                        showingManualImportSheet = false
                    }
                    .fontWeight(.bold)
                    .disabled(manualImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Actions & Logic

    private func autoLoadWalkthroughIfNeeded() async {
        guard !hasCheckedSupabase else { return }
        hasCheckedSupabase = true
        guard walkthroughItems.isEmpty else { return }

        isCheckingSupabase = true
        defer { isCheckingSupabase = false }

        let igdbID = game.igdbID ?? remoteIGDBID
        if let template = try? await SupabaseSyncService.shared.fetchWalkthroughTemplate(igdbId: igdbID, title: game.title),
           !template.items.isEmpty {
            var copy = game
            let generated = template.toTodoItems()
            copy.todos = generated + personalTodoItems
            onUpdateGame(copy)
        }
    }

    private func toggleStep(_ item: GameTodoItem) {
        var copy = game
        guard let idx = copy.todos.firstIndex(where: { $0.id == item.id }) else { return }
        copy.todos[idx].isDone.toggle()

        // Synka "Var är du i spelet?" automatiskt baserat på kapitelprocent (utan att någonsin sätta .completed under Spelar nu)
        let wt = copy.todos.filter { $0.chapterGroup != nil || $0.order != nil }
        if !wt.isEmpty && copy.status == .playing {
            let doneCount = wt.filter(\.isDone).count
            let ratio = Double(doneCount) / Double(wt.count)
            if ratio < 0.25 {
                copy.storyProgress = .justStarted
            } else if ratio < 0.75 {
                copy.storyProgress = .midway
            } else {
                copy.storyProgress = .nearEnd
            }
            // Sätt även aktuell akt/kapitel som progressNote om fältet är tomt
            if let next = wt.sorted(by: { ($0.order ?? 9999) < ($1.order ?? 9999) }).first(where: { !$0.isDone }) {
                copy.progressNote = next.title
                copy.noteUpdatedAt = Date()
            }
        }

        onUpdateGame(copy)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteStep(_ item: GameTodoItem) {
        var copy = game
        copy.todos.removeAll(where: { $0.id == item.id })
        onUpdateGame(copy)
    }

    private func addCustomStep() {
        let trimmedTitle = newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedGroup = newStepGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackGroup = actSections.last?.name ?? "Huvudberättelsen"
        let group = trimmedGroup.isEmpty ? fallbackGroup : trimmedGroup
        let nextOrder = (walkthroughItems.compactMap(\.order).max() ?? walkthroughItems.count) + 1

        var copy = game
        copy.todos.append(
            GameTodoItem(
                title: trimmedTitle,
                isDone: false,
                order: nextOrder,
                chapterGroup: group
            )
        )
        onUpdateGame(copy)
        newStepTitle = ""
    }

    private func importManualLines() {
        guard let targetIgdbId = game.igdbID ?? remoteIGDBID else { return }
        let lines = manualImportText.components(separatedBy: .newlines)
        var currentGroup = "Huvudberättelsen"
        var items: [GameWalkthroughTemplateItem] = []
        var orderCounter = 1

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#") {
                currentGroup = line.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                continue
            }
            if line.hasSuffix(":") && line.count < 45 {
                currentGroup = String(line.dropLast())
                continue
            }

            let cleaned = line.replacingOccurrences(of: "^(\\d+[\\.)]|[-•*])\\s*", with: "", options: .regularExpression)
            guard !cleaned.isEmpty else { continue }
            items.append(
                GameWalkthroughTemplateItem(
                    id: UUID().uuidString,
                    title: cleaned,
                    order: orderCounter,
                    chapterGroup: currentGroup,
                    description: nil,
                    isOptional: false
                )
            )
            orderCounter += 1
        }

        guard !items.isEmpty else { return }
        let template = GameWalkthroughTemplate(
            igdbId: targetIgdbId,
            title: game.title,
            normalizedTitle: GameWalkthroughTemplate.normalizeTitle(game.title),
            alternateIgdbIds: nil,
            hasLinearProgression: true,
            progressionType: "chapters",
            summary: "Manuell import",
            items: items,
            source: "Manuell import",
            sourceUrl: nil
        )

        var copy = game
        copy.todos = template.toTodoItems() + personalTodoItems
        onUpdateGame(copy)

        Task {
            _ = try? await SupabaseSyncService.shared.upsertWalkthroughTemplate(template)
        }
    }

    private func generateWithGeminiAI() async {
        guard let targetIgdbId = game.igdbID ?? remoteIGDBID else { return }
        let key = geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        isGeneratingAI = true
        aiErrorMessage = nil
        defer { isGeneratingAI = false }

        do {
            let prompt = """
            Returnera en komplett 1:1 walkthrough-kapitellista (varje enskilt huvuduppdrag/kapitel i rätt ordning, exakt som IGN Walkthrough) för spelet "\(game.title)".
            Klumpa ALDRIG ihop flera uppdrag på samma rad. Behåll de officiella engelska kapitel-/uppdragsnamnen men översätt akt-/delrubriker (`chapterGroup`) till svenska (t.ex. "Akt 1: ...", "Prolog", "Epilog").
            Svara ENDAST med giltig JSON i exakt detta format:
            {"steps":[{"order":1,"title":"...","chapterGroup":"..."}]}
            """

            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)") else {
                throw URLError(.badURL)
            }

            let payload: [String: Any] = [
                "contents": [
                    ["parts": [["text": prompt]]]
                ],
                "generationConfig": [
                    "temperature": 0.1,
                    "responseMimeType": "application/json"
                ]
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            struct GeminiCandidateResponse: Decodable {
                struct Candidate: Decodable {
                    struct Content: Decodable {
                        struct Part: Decodable { let text: String? }
                        let parts: [Part]?
                    }
                    let content: Content?
                }
                let candidates: [Candidate]?
            }

            struct GeminiStepItem: Decodable {
                let order: Int
                let title: String
                let chapterGroup: String?
            }

            struct StepsWrapper: Decodable {
                let steps: [GeminiStepItem]
            }

            let geminiResp = try JSONDecoder().decode(GeminiCandidateResponse.self, from: data)
            guard let jsonText = geminiResp.candidates?.first?.content?.parts?.first?.text,
                  let jsonData = jsonText.data(using: .utf8) else {
                throw URLError(.cannotParseResponse)
            }

            let decoded = try JSONDecoder().decode(StepsWrapper.self, from: jsonData)
            guard !decoded.steps.isEmpty else {
                throw URLError(.cannotParseResponse)
            }

            let templateItems = decoded.steps.map { step in
                GameWalkthroughTemplateItem(
                    id: UUID().uuidString,
                    title: step.title,
                    order: step.order,
                    chapterGroup: step.chapterGroup,
                    description: nil,
                    isOptional: false
                )
            }

            let template = GameWalkthroughTemplate(
                igdbId: targetIgdbId,
                title: game.title,
                normalizedTitle: GameWalkthroughTemplate.normalizeTitle(game.title),
                alternateIgdbIds: nil,
                hasLinearProgression: true,
                progressionType: "chapters",
                summary: "AI (IGN 1:1)",
                items: templateItems,
                source: "AI (IGN 1:1)",
                sourceUrl: nil
            )

            var copy = game
            copy.todos = template.toTodoItems() + personalTodoItems
            onUpdateGame(copy)

            _ = try? await SupabaseSyncService.shared.upsertWalkthroughTemplate(template)
        } catch {
            aiErrorMessage = "Kunde inte hämta lista med AI (\(error.localizedDescription))."
        }
    }
}
