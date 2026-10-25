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

    // Expansion per group
    @State private var isMainQuestsExpanded = false
    @State private var isSideQuestsExpanded = false
    @State private var isPersonalGoalsExpanded = false

    // Sheets & Editing
    @State private var showingAddModal = false
    @State private var newStepTitle = ""
    @State private var selectedCategory: TaskCategory = .main
    @State private var showingManualImportSheet = false
    @State private var manualImportText = ""
    @State private var showingAPIKeyPrompt = false
    @State private var apiKeyDraft = ""
    @State private var showingManageSheet = false
    @State private var showingEditSingleSheet = false
    @State private var showingClearConfirmation = false
    @State private var itemToEdit: GameTodoItem? = nil
    @State private var editDraftTitle = ""
    @State private var editDraftCategory: TaskCategory = .main

    enum TaskCategory: String, CaseIterable, Identifiable {
        case main = "Huvuduppdrag"
        case side = "Sidouppdrag"
        case goal = "Eget mål"

        var id: String { rawValue }
    }

    // MARK: - Filtered Categories

    private var mainQuests: [GameTodoItem] {
        game.todos.filter { item in
            if item.isOptional || item.chapterGroup == "Sidouppdrag" || item.chapterGroup == "Egna mål" {
                return false
            }
            if item.chapterGroup == nil && item.order == nil {
                let hasStructured = game.todos.contains { $0.chapterGroup != nil || $0.order != nil }
                return !hasStructured
            }
            return true
        }
        .sorted { ($0.order ?? 9999) < ($1.order ?? 9999) }
    }

    private var sideQuests: [GameTodoItem] {
        game.todos.filter { item in
            item.isOptional || item.chapterGroup == "Sidouppdrag"
        }
        .sorted { ($0.order ?? 9999) < ($1.order ?? 9999) }
    }

    private var personalGoals: [GameTodoItem] {
        game.todos.filter { item in
            if item.chapterGroup == "Egna mål" { return true }
            let hasStructured = game.todos.contains { $0.chapterGroup != nil || $0.order != nil }
            return hasStructured && item.chapterGroup == nil && item.order == nil
        }
        .sorted { ($0.order ?? 9999) < ($1.order ?? 9999) }
    }

    private var allTodos: [GameTodoItem] {
        mainQuests + sideQuests + personalGoals
    }

    private var totalCount: Int {
        allTodos.count
    }

    private var completedCount: Int {
        allTodos.filter(\.isDone).count
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Rubrikrad ovanför kortet
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Kapitel & uppdrag")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                if totalCount > 0 {
                    Text("· \(completedCount) av \(totalCount)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if totalCount > 0 {
                    Menu {
                        Button {
                            showingManageSheet = true
                        } label: {
                            Label("Hantera lista...", systemImage: "list.bullet.rectangle")
                        }

                        Button {
                            manualImportText = ""
                            showingManualImportSheet = true
                        } label: {
                            Label("Klistra in ny lista", systemImage: "doc.on.clipboard")
                        }

                        Button {
                            if geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                apiKeyDraft = ""
                                showingAPIKeyPrompt = true
                            } else {
                                Task { await generateWithGeminiAI() }
                            }
                        } label: {
                            Label("Hämta med AI", systemImage: "sparkles")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Börja om från början", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Huvudkort
            VStack(alignment: .leading, spacing: 14) {
                // Röd progressbar i toppen av kortet
                if totalCount > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 7)

                            let ratio = CGFloat(Double(completedCount) / Double(totalCount))
                            let fillWidth = max(7, geo.size.width * ratio)
                            Capsule()
                                .fill(Color.red)
                                .frame(width: fillWidth, height: 7)
                        }
                    }
                    .frame(height: 7)
                    .padding(.top, 2)
                }

                if isCheckingSupabase && totalCount == 0 {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Kontrollerar verifierad kapitellista...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if totalCount == 0 {
                    emptyStateView
                } else {
                    // Grupp 1: HUVUDUPPDRAG
                    if !mainQuests.isEmpty {
                        questGroupSection(
                            title: "HUVUDUPPDRAG",
                            items: mainQuests,
                            isExpanded: isMainQuestsExpanded,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    isMainQuestsExpanded.toggle()
                                }
                            }
                        )
                    }

                    // Grupp 2: SIDOUUPPDRAG
                    if !sideQuests.isEmpty {
                        questGroupSection(
                            title: "SIDOUUPPDRAG",
                            items: sideQuests,
                            isExpanded: isSideQuestsExpanded,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    isSideQuestsExpanded.toggle()
                                }
                            }
                        )
                    }

                    // Grupp 3: EGNA MÅL
                    if !personalGoals.isEmpty {
                        questGroupSection(
                            title: "EGNA MÅL",
                            items: personalGoals,
                            isExpanded: isPersonalGoalsExpanded,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    isPersonalGoalsExpanded.toggle()
                                }
                            }
                        )
                    }
                }

                // Avgränsare och bottenåtgärd
                Divider()
                    .opacity(0.4)
                    .padding(.top, 2)

                Button {
                    newStepTitle = ""
                    selectedCategory = .main
                    showingAddModal = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.subheadline.bold())
                        Text("Lägg till kapitel eller uppdrag")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.red)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let err = aiErrorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
        }
        .task(id: game.id) {
            await autoLoadWalkthroughIfNeeded()
        }
        .sheet(isPresented: $showingAddModal) {
            addChapterOrQuestSheet
        }
        .sheet(isPresented: $showingManualImportSheet) {
            manualImportSheetView
        }
        .sheet(isPresented: $showingManageSheet) {
            manageListSheet
        }
        .sheet(isPresented: $showingEditSingleSheet) {
            editSingleItemSheet
        }
        .confirmationDialog(
            "Börja om från början?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Rensa alla kapitel och börja om", role: .destructive) {
                clearAllTodos()
                showingManageSheet = false
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Detta tar bort alla kapitel och uppdrag för \(game.title). Du kan sedan klistra in en ny lista eller hämta med AI.")
        }
        .sheet(isPresented: $showingAPIKeyPrompt) {
            apiKeySheet
        }
    }

    // MARK: - Quest Group Section

    private func questGroupSection(
        title: String,
        items: [GameTodoItem],
        isExpanded: Bool,
        onToggleExpand: @escaping () -> Void
    ) -> some View {
        let doneCount = items.filter(\.isDone).count
        let total = items.count

        let displayItems: [GameTodoItem] = {
            if isExpanded || total <= 4 {
                return items
            }
            // Visa de senaste 2 avklarade och de kommande 2 oavklarade
            let completed = items.filter(\.isDone)
            let uncompleted = items.filter { !$0.isDone }
            var result: [GameTodoItem] = []
            if !completed.isEmpty {
                result.append(contentsOf: completed.suffix(2))
            }
            result.append(contentsOf: uncompleted.prefix(max(2, 4 - result.count)))
            return result
        }()

        return VStack(alignment: .leading, spacing: 8) {
            // Grupprubrik (t.ex. HUVUDUPPDRAG · 5/12)
            Text("\(title) · \(doneCount)/\(total)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 30)
                            .opacity(0.35)
                    }

                    HStack(spacing: 12) {
                        Button {
                            toggleStep(item)
                        } label: {
                            Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(item.isDone ? Color.secondary : Color.secondary)
                        }
                        .buttonStyle(.plain)

                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(item.isDone ? Color.secondary : Color.primary)
                            .strikethrough(item.isDone, color: Color.secondary)
                            .lineLimit(2)

                        Spacer()

                        Menu {
                            Button {
                                itemToEdit = item
                                editDraftTitle = item.title
                                editDraftCategory = category(for: item)
                                showingEditSingleSheet = true
                            } label: {
                                Label("Redigera", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteStep(item)
                            } label: {
                                Label("Ta bort", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.secondary.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 7)
                    .contextMenu {
                        Button {
                            itemToEdit = item
                            editDraftTitle = item.title
                            editDraftCategory = category(for: item)
                            showingEditSingleSheet = true
                        } label: {
                            Label("Redigera", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            deleteStep(item)
                        } label: {
                            Label("Ta bort", systemImage: "trash")
                        }
                    }
                }
            }

            // Visa alla X ›-knapp om det finns fler än 4 punkter
            if total > 4 {
                Button {
                    onToggleExpand()
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Visa färre" : "Visa alla \(total)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.red)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.red)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingen kapitellista inlagd än för detta spel.")
                .font(.subheadline)
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(.tertiarySystemFill))
                    .foregroundStyle(.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Add Chapter or Quest Sheet

    private var addChapterOrQuestSheet: some View {
        NavigationStack {
            Form {
                Section("Nytt uppdrag eller mål") {
                    TextField("Titel på uppdraget...", text: $newStepTitle)
                        .font(.body)

                    Picker("Kategori", selection: $selectedCategory) {
                        ForEach(TaskCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }

                Section("Importera eller hämta lista") {
                    Button {
                        showingAddModal = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            manualImportText = ""
                            showingManualImportSheet = true
                        }
                    } label: {
                        Label("Klistra in kapitellista", systemImage: "doc.on.clipboard")
                            .foregroundStyle(.primary)
                    }

                    Button {
                        showingAddModal = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                apiKeyDraft = ""
                                showingAPIKeyPrompt = true
                            } else {
                                Task { await generateWithGeminiAI() }
                            }
                        }
                    } label: {
                        HStack {
                            Label("Hämta 1:1-guide med AI", systemImage: "sparkles")
                                .foregroundStyle(.red)
                            Spacer()
                            if isGeneratingAI {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    if totalCount > 0 {
                        Button(role: .destructive) {
                            showingAddModal = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingClearConfirmation = true
                            }
                        } label: {
                            Label("Börja om från början (Rensa)", systemImage: "arrow.counterclockwise")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Lägg till uppdrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        showingAddModal = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        saveNewStep()
                        showingAddModal = false
                    }
                    .fontWeight(.bold)
                    .disabled(newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var manualImportSheetView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Klistra in kapitel eller uppdrag (en per rad). Rader som börjar med '#' eller slutar med ':' tolkas som akt-/gruppnamn.")
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

    private var manageListSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(game.todos) { item in
                        HStack(spacing: 12) {
                            Button {
                                toggleStep(item)
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(item.isDone ? Color.green : Color.secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(item.isDone ? Color.secondary : Color.primary)
                                    .strikethrough(item.isDone, color: Color.secondary)

                                if let group = item.chapterGroup, !group.isEmpty {
                                    Text(group)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                itemToEdit = item
                                editDraftTitle = item.title
                                editDraftCategory = category(for: item)
                                showingEditSingleSheet = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in
                        deleteSteps(at: indexSet)
                    }
                    .onMove { source, destination in
                        moveSteps(from: source, to: destination)
                    }
                } header: {
                    Text("Alla kapitel & uppdrag (\(game.todos.count))")
                } footer: {
                    Text("Svep åt vänster på en rad för att ta bort den. Tryck på pennan för att ändra texten eller kategorin. Använd Ändra för att dra och byta ordning.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Börja om från början (Rensa lista)", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Hantera kapitellista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") {
                        showingManageSheet = false
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var editSingleItemSheet: some View {
        NavigationStack {
            Form {
                Section("Titel") {
                    TextField("Titel på kapitel/uppdrag...", text: $editDraftTitle)
                        .font(.body)

                    Picker("Kategori", selection: $editDraftCategory) {
                        ForEach(TaskCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        if let item = itemToEdit {
                            deleteStep(item)
                        }
                        showingEditSingleSheet = false
                        itemToEdit = nil
                    } label: {
                        HStack {
                            Spacer()
                            Label("Ta bort detta kapitel", systemImage: "trash")
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Redigera uppdrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        showingEditSingleSheet = false
                        itemToEdit = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        if let item = itemToEdit {
                            editStep(item: item, newTitle: editDraftTitle, newCategory: editDraftCategory)
                        }
                        showingEditSingleSheet = false
                        itemToEdit = nil
                    }
                    .fontWeight(.bold)
                    .disabled(editDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var apiKeySheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("För att generera 1:1-kapitellistor med AI behövs en gratis Gemini API-nyckel från Google AI Studio. Den sparas lokalt på din enhet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("Klistra in AIzaSy...", text: $apiKeyDraft)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .textContentType(.none)
                            .keyboardType(.asciiCapable)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )

                        Button {
                            if let clip = UIPasteboard.general.string {
                                apiKeyDraft = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.subheadline.bold())
                                Text("Klistra in")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    if !apiKeyDraft.isEmpty {
                        HStack {
                            Button {
                                apiKeyDraft = ""
                            } label: {
                                Text("Rensa text")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            if !geminiApiKey.isEmpty && apiKeyDraft != geminiApiKey {
                                Button("Återställ sparad") {
                                    apiKeyDraft = geminiApiKey
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                        Text("Skaffa en gratis Gemini API-nyckel här (Google AI Studio)")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(20)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Gemini API-nyckel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        showingAPIKeyPrompt = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara & Hämta") {
                        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            geminiApiKey = trimmed
                            showingAPIKeyPrompt = false
                            Task { await generateWithGeminiAI() }
                        }
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.red)
                    .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                apiKeyDraft = geminiApiKey
            }
        }
        .presentationDetents([.height(310), .medium])
    }

    // MARK: - Actions & Logic

    private func category(for item: GameTodoItem) -> TaskCategory {
        if item.chapterGroup == "Egna mål" {
            return .goal
        }
        if item.isOptional || item.chapterGroup == "Sidouppdrag" {
            return .side
        }
        return .main
    }

    private func deleteStep(_ item: GameTodoItem) {
        var copy = game
        copy.todos.removeAll(where: { $0.id == item.id })
        syncProgress(for: &copy)
        onUpdateGame(copy)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func deleteSteps(at offsets: IndexSet) {
        var copy = game
        copy.todos.remove(atOffsets: offsets)
        for (idx, _) in copy.todos.enumerated() {
            if copy.todos[idx].order != nil {
                copy.todos[idx].order = idx + 1
            }
        }
        syncProgress(for: &copy)
        onUpdateGame(copy)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func moveSteps(from source: IndexSet, to destination: Int) {
        var copy = game
        copy.todos.move(fromOffsets: source, toOffset: destination)
        for (idx, _) in copy.todos.enumerated() {
            if copy.todos[idx].order != nil {
                copy.todos[idx].order = idx + 1
            }
        }
        onUpdateGame(copy)
    }

    private func editStep(item: GameTodoItem, newTitle: String, newCategory: TaskCategory) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var copy = game
        if let idx = copy.todos.firstIndex(where: { $0.id == item.id }) {
            copy.todos[idx].title = trimmed
            switch newCategory {
            case .main:
                copy.todos[idx].chapterGroup = "Huvudberättelsen"
                copy.todos[idx].isOptional = false
            case .side:
                copy.todos[idx].chapterGroup = "Sidouppdrag"
                copy.todos[idx].isOptional = true
            case .goal:
                copy.todos[idx].chapterGroup = "Egna mål"
                copy.todos[idx].isOptional = false
            }
        }
        syncProgress(for: &copy)
        onUpdateGame(copy)
    }

    private func clearAllTodos() {
        var copy = game
        copy.todos = []
        copy.progressNote = nil
        onUpdateGame(copy)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func syncProgress(for copy: inout Game) {
        let all = copy.todos
        if all.isEmpty {
            copy.progressNote = nil
            return
        }
        if copy.status == .playing {
            let done = all.filter(\.isDone).count
            let ratio = Double(done) / Double(all.count)
            if ratio < 0.25 {
                copy.storyProgress = .justStarted
            } else if ratio < 0.75 {
                copy.storyProgress = .midway
            } else {
                copy.storyProgress = .nearEnd
            }
            if let next = all.first(where: { !$0.isDone }) {
                copy.progressNote = next.title
                copy.noteUpdatedAt = Date()
            } else {
                copy.progressNote = "Alla uppdrag klara"
            }
        }
    }

    private func autoLoadWalkthroughIfNeeded() async {
        guard !hasCheckedSupabase else { return }
        hasCheckedSupabase = true
        guard totalCount == 0 else { return }

        isCheckingSupabase = true
        defer { isCheckingSupabase = false }

        let targetId = game.igdbID ?? remoteIGDBID ?? abs(game.title.hashValue)
        if let template = try? await SupabaseSyncService.shared.fetchWalkthroughTemplate(igdbId: targetId, title: game.title),
           !template.items.isEmpty {
            var copy = game
            let generated = template.toTodoItems()
            copy.todos = generated + personalGoals
            onUpdateGame(copy)
        }
    }

    private func toggleStep(_ item: GameTodoItem) {
        var copy = game
        guard let idx = copy.todos.firstIndex(where: { $0.id == item.id }) else { return }
        copy.todos[idx].isDone.toggle()
        syncProgress(for: &copy)
        onUpdateGame(copy)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func saveNewStep() {
        let trimmedTitle = newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        var copy = game
        let nextOrder = (copy.todos.compactMap(\.order).max() ?? copy.todos.count) + 1

        let newItem: GameTodoItem
        switch selectedCategory {
        case .main:
            newItem = GameTodoItem(
                title: trimmedTitle,
                isDone: false,
                order: nextOrder,
                chapterGroup: "Huvudberättelsen",
                isOptional: false
            )
        case .side:
            newItem = GameTodoItem(
                title: trimmedTitle,
                isDone: false,
                order: nextOrder,
                chapterGroup: "Sidouppdrag",
                isOptional: true
            )
        case .goal:
            newItem = GameTodoItem(
                title: trimmedTitle,
                isDone: false,
                order: nil,
                chapterGroup: "Egna mål",
                isOptional: false
            )
        }

        copy.todos.append(newItem)
        onUpdateGame(copy)
        newStepTitle = ""
    }

    private func importManualLines() {
        let targetIgdbId = game.igdbID ?? remoteIGDBID ?? abs(game.title.hashValue)
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
        copy.todos = template.toTodoItems() + personalGoals
        onUpdateGame(copy)

        Task {
            _ = try? await SupabaseSyncService.shared.upsertWalkthroughTemplate(template)
        }
    }

    private func generateWithGeminiAI() async {
        let targetIgdbId = game.igdbID ?? remoteIGDBID ?? abs(game.title.hashValue)
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
            copy.todos = template.toTodoItems() + personalGoals
            onUpdateGame(copy)

            _ = try? await SupabaseSyncService.shared.upsertWalkthroughTemplate(template)
        } catch {
            aiErrorMessage = "Kunde inte hämta lista med AI (\(error.localizedDescription))."
        }
    }
}
