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
    @AppStorage("walkthrough_spoiler_protection") private var spoilerProtection: Bool = true

    @State private var isCheckingSupabase = false
    @State private var hasCheckedSupabase = false
    @State private var isGeneratingAI = false
    @State private var aiErrorMessage: String? = nil

    // Expansion per group & Spoiler states
    @State private var isMainQuestsExpanded = false
    @State private var isSideQuestsExpanded = false
    @State private var isPersonalGoalsExpanded = false
    @State private var revealedItemIds: Set<UUID> = []
    @State private var collapsedActGroups: Set<String> = []

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

    struct ActGroupInfo: Identifiable {
        var id: String { name }
        let name: String
        let majorAct: String
        let items: [GameTodoItem]
        let done: Int
        let total: Int
        var isCompleted: Bool { done == total && total > 0 }
    }

    struct MajorActInfo {
        let name: String
        var done: Int
        var total: Int
        var isCompleted: Bool { done == total && total > 0 }
    }

    // MARK: - Filtered Categories & Act Logic

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

    /// Extraherar överordnad Huvudakt (t.ex. "Akt 2 (Panam & Hellman)" -> "Akt 2", "Akt 1: Trosky" -> "Akt 1")
    /// så att alla parallella uppdragsspår inom samma akt låses upp samtidigt.
    private func majorActName(for chapterGroup: String?) -> String {
        guard let raw = chapterGroup?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "Huvudberättelsen"
        }
        let pattern = "^(Akt\\s*\\d+|Act\\s*\\d+|Del\\s*\\d+|Part\\s*\\d+|Kapitel\\s*\\d+|Chapter\\s*\\d+|Prolog|Prologue|Epilog|Epilogue|Final|Byn|Slottet|Ön|Sommar|Höst|Vinter|Vår)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: raw, options: [], range: NSRange(raw.startIndex..., in: raw)),
           let range = Range(match.range(at: 1), in: raw) {
            return String(raw[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let beforeParen = raw.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? raw
        let beforeColon = beforeParen.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? beforeParen
        return beforeColon.isEmpty ? "Huvudberättelsen" : beforeColon
    }

    private var actGroups: [ActGroupInfo] {
        var orderKeys: [String] = []
        var grouped: [String: [GameTodoItem]] = [:]
        for item in mainQuests {
            let g = (item.chapterGroup?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Huvudberättelsen"
            if grouped[g] == nil {
                orderKeys.append(g)
                grouped[g] = []
            }
            grouped[g]?.append(item)
        }
        return orderKeys.compactMap { key in
            guard let list = grouped[key] else { return nil }
            let done = list.filter(\.isDone).count
            return ActGroupInfo(
                name: key,
                majorAct: majorActName(for: key),
                items: list,
                done: done,
                total: list.count
            )
        }
    }

    private var majorActs: [MajorActInfo] {
        var list: [MajorActInfo] = []
        for item in mainQuests {
            let mName = majorActName(for: item.chapterGroup)
            if let idx = list.firstIndex(where: { $0.name.caseInsensitiveCompare(mName) == .orderedSame }) {
                list[idx].total += 1
                if item.isDone { list[idx].done += 1 }
            } else {
                list.append(MajorActInfo(name: mName, done: item.isDone ? 1 : 0, total: 1))
            }
        }
        return list
    }

    private var activeMajorActIndex: Int {
        majorActs.firstIndex(where: { !$0.isCompleted }) ?? majorActs.count
    }

    private var activeMajorActName: String? {
        let idx = activeMajorActIndex
        guard idx < majorActs.count else { return nil }
        return majorActs[idx].name
    }

    private var currentMainQuestIndex: Int {
        mainQuests.firstIndex(where: { !$0.isDone }) ?? mainQuests.count
    }

    private func isItemHiddenBySpoiler(_ item: GameTodoItem, flatIndex: Int) -> Bool {
        guard spoilerProtection else { return false }
        if item.isDone { return false }
        if revealedItemIds.contains(item.id) { return false }

        if majorActs.count > 1 {
            let itemMajor = majorActName(for: item.chapterGroup)
            if let actIdx = majorActs.firstIndex(where: { $0.name.caseInsensitiveCompare(itemMajor) == .orderedSame }) {
                // Alla uppdrag i den aktiva huvudakten (och tidigare akter) är upplåsta samtidigt
                return actIdx > activeMajorActIndex
            }
        }

        return flatIndex > currentMainQuestIndex
    }

    private func toggleReveal(_ id: UUID) {
        if revealedItemIds.contains(id) {
            revealedItemIds.remove(id)
        } else {
            revealedItemIds.insert(id)
        }
    }

    private func toggleActGroupCollapse(_ groupName: String) {
        if collapsedActGroups.contains(groupName) {
            collapsedActGroups.remove(groupName)
        } else {
            collapsedActGroups.insert(groupName)
        }
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
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            spoilerProtection.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: spoilerProtection ? "shield.fill" : "shield.slash")
                                .font(.system(size: 11, weight: .bold))
                            Text(spoilerProtection ? "Spoilerskydd PÅ" : "Spoilerskydd AV")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            spoilerProtection
                                ? Color.orange.opacity(0.16)
                                : Color(.tertiarySystemFill)
                        )
                        .foregroundStyle(spoilerProtection ? Color.orange : Color.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

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
                    // Grupp 1: HUVUDUPPDRAG (med akt-hantering & spoilerskydd)
                    if !mainQuests.isEmpty {
                        mainQuestsSection
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

    // MARK: - Main Quests Section (Act-Aware & Spoiler Protected)

    private var mainQuestsSection: some View {
        let doneCount = mainQuests.filter(\.isDone).count
        let total = mainQuests.count
        let hasMultipleGroups = actGroups.count > 1

        // Kompakt förhandsvisning som tar med nästa uppdrag från VARJE aktivt spår i den aktiva akten (t.ex. Cyberpunk 2077 Akt 2)
        let compactItems: [GameTodoItem] = {
            if total <= 4 {
                return mainQuests
            }
            var result: [GameTodoItem] = []
            let completed = mainQuests.filter(\.isDone)
            if let lastDone = completed.last {
                result.append(lastDone)
            }

            if hasMultipleGroups, let activeAct = activeMajorActName {
                let activeBranches = actGroups.filter {
                    $0.majorAct.caseInsensitiveCompare(activeAct) == .orderedSame && !$0.isCompleted
                }
                if activeBranches.count > 1 {
                    // Ta nästa oavklarade uppdrag från varje parallellt spår i akten (t.ex. Judy, Voodoo Boys, Panam, Takemura)
                    for branch in activeBranches {
                        if let nextInBranch = branch.items.first(where: { !$0.isDone }),
                           !result.contains(where: { $0.id == nextInBranch.id }) {
                            result.append(nextInBranch)
                        }
                    }
                }
            }

            let uncompleted = mainQuests.filter { !$0.isDone }
            for item in uncompleted where result.count < 4 {
                if !result.contains(where: { $0.id == item.id }) {
                    result.append(item)
                }
            }
            return result
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("HUVUDUPPDRAG · \(doneCount)/\(total)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                if let activeAct = activeMajorActName, majorActs.count > 1 {
                    Text("· Aktiv: \(activeAct)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.red)
                }

                Spacer()
            }

            if spoilerProtection && majorActs.count > 1 && isMainQuestsExpanded {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("Aktiv akt: **\(activeMajorActName ?? "Klar")** — alla uppdrag i akten är synliga i valfri ordning, medan kommande akter skyddas.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(.tertiarySystemFill).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if isMainQuestsExpanded && hasMultipleGroups {
                // Grupperad akt-vy (som i webbtestet för Cyberpunk 2077, KCD 2, Witcher 3 m.fl.)
                VStack(spacing: 10) {
                    ForEach(actGroups) { group in
                        let isCollapsed = collapsedActGroups.contains(group.name)
                        let isCurrentAct = (activeMajorActName != nil)
                            && group.majorAct.caseInsensitiveCompare(activeMajorActName ?? "") == .orderedSame
                            && !group.isCompleted

                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    toggleActGroupCollapse(group.name)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.secondary)

                                    Text(group.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    if isCurrentAct {
                                        Text("Aktiv akt")
                                            .font(.system(size: 9, weight: .bold))
                                            .textCase(.uppercase)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.16))
                                            .foregroundStyle(Color.red)
                                            .clipShape(Capsule())
                                    } else if group.isCompleted {
                                        HStack(spacing: 3) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                            Text("Klar")
                                                .font(.system(size: 9, weight: .bold))
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.16))
                                        .foregroundStyle(Color.green)
                                        .clipShape(Capsule())
                                    }

                                    Spacer()

                                    Text("\(group.done)/\(group.total)")
                                        .font(.caption.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.tertiarySystemFill).opacity(0.55))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if !isCollapsed {
                                VStack(spacing: 0) {
                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, item in
                                        let flatIdx = mainQuests.firstIndex(where: { $0.id == item.id }) ?? idx
                                        let hiddenBySpoiler = isItemHiddenBySpoiler(item, flatIndex: flatIdx)

                                        if idx > 0 {
                                            Divider()
                                                .padding(.leading, 38)
                                                .opacity(0.35)
                                        }

                                        questRowView(
                                            item: item,
                                            flatIndex: flatIdx,
                                            isHiddenBySpoiler: hiddenBySpoiler,
                                            showGroupBadge: false
                                        )
                                        .padding(.horizontal, 12)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .background(Color(.systemBackground).opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    isCurrentAct
                                        ? Color.red.opacity(0.45)
                                        : (group.isCompleted ? Color.green.opacity(0.3) : Color.primary.opacity(0.08)),
                                    lineWidth: 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else {
                // Kompakt vy eller enkel kronologisk lista
                let listToShow = isMainQuestsExpanded ? mainQuests : compactItems
                VStack(spacing: 0) {
                    ForEach(Array(listToShow.enumerated()), id: \.element.id) { index, item in
                        let flatIdx = mainQuests.firstIndex(where: { $0.id == item.id }) ?? index
                        let hiddenBySpoiler = isItemHiddenBySpoiler(item, flatIndex: flatIdx)

                        if index > 0 {
                            Divider()
                                .padding(.leading, 30)
                                .opacity(0.35)
                        }

                        questRowView(
                            item: item,
                            flatIndex: flatIdx,
                            isHiddenBySpoiler: hiddenBySpoiler,
                            showGroupBadge: hasMultipleGroups && !isMainQuestsExpanded
                        )
                    }
                }
            }

            if total > 4 {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isMainQuestsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(
                            isMainQuestsExpanded
                                ? "Visa färre"
                                : (hasMultipleGroups ? "Visa alla \(total) (\(actGroups.count) akter/delar)" : "Visa alla \(total)")
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.red)
                        Image(systemName: isMainQuestsExpanded ? "chevron.up" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.red)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func questRowView(
        item: GameTodoItem,
        flatIndex: Int,
        isHiddenBySpoiler: Bool,
        showGroupBadge: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleStep(item)
            } label: {
                Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(item.isDone ? Color.secondary : Color.secondary)
            }
            .buttonStyle(.plain)

            if isHiddenBySpoiler {
                HStack(spacing: 6) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange.opacity(0.8))
                    Text("Delmål \(flatIndex + 1) (Dold av spoilerskydd)")
                        .font(.subheadline.italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            toggleReveal(item.id)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "eye")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Visa")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.14))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(item.isDone ? Color.secondary : Color.primary)
                            .strikethrough(item.isDone, color: Color.secondary)
                            .lineLimit(2)

                        if spoilerProtection && revealedItemIds.contains(item.id) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    toggleReveal(item.id)
                                }
                            } label: {
                                Image(systemName: "eye.slash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if showGroupBadge,
                       let group = item.chapterGroup?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !group.isEmpty,
                       group != "Huvudberättelsen" {
                        Text(group)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

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
                        PasteableTextField(placeholder: "Klistra in AIzaSy...", text: $apiKeyDraft)
                            .frame(height: 24)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
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
                let existingGroup = copy.todos[idx].chapterGroup
                if existingGroup == nil || existingGroup == "Sidouppdrag" || existingGroup == "Egna mål" {
                    copy.todos[idx].chapterGroup = activeMajorActName ?? "Huvudberättelsen"
                }
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

    private func extractGeminiVersion(_ name: String) -> Double {
        guard let regex = try? NSRegularExpression(pattern: "gemini[^\\d]*(\\d+(?:\\.\\d+)?)", options: [.caseInsensitive]),
              let match = regex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: name),
              let version = Double(name[range]) else {
            return 0
        }
        return version
    }

    private func generateWithGeminiAI() async {
        let targetIgdbId = game.igdbID ?? remoteIGDBID ?? abs(game.title.hashValue)
        let cleanKey = geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return }

        isGeneratingAI = true
        aiErrorMessage = nil
        defer { isGeneratingAI = false }

        let title = game.title
        let encodedKey = cleanKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanKey

        let prompt = """
        Task: Create the COMPLETE, chronological 1:1 main story walkthrough progression list for the video game "\(title)", structured like IGN's official Walkthrough guide.

        STRICT RULES:
        1. COMPLETE 1:1 LIST (NO LUMPING, NO SKIPPING):
           - Include EVERY official main story chapter, main quest, or walkthrough area in chronological order from start to finish.
           - NEVER combine two chapters, quests, or areas into one item (e.g., NEVER write "Chapter 1 & 2"). Each must be its own separate object in "items".
        2. EXCLUDE MINOR SIDE CONTENT:
           - Only include main story chapters/quests/areas (plus major optional boss areas if relevant, marked with "isOptional": true).
        3. OFFICIAL ENGLISH TITLES:
           - Keep the official English in-game/IGN titles for all chapters, quests, and areas. Do not translate titles to Swedish!
        4. ACT / PHASE GROUPING ("chapterGroup"):
           - Group every item into its overarching Act, Phase, or Region using "chapterGroup" (e.g., "Prolog", "Akt 1", "Akt 2", "Akt 3", "Final").
        5. Output ONLY valid JSON matching this exact schema:
        {
          "gameTitle": "\(title)",
          "hasLinearProgression": true,
          "progressionType": "chapters",
          "summary": "Kort svensk sammanfattning av spelets upplägg",
          "items": [
            {
              "id": "1",
              "title": "Exact English Chapter / Quest / Area Title",
              "order": 1,
              "chapterGroup": "Akt 1",
              "description": "Kort svensk info",
              "isOptional": false
            }
          ]
        }
        """

        struct GeminiModelsListResponse: Decodable {
            struct ModelInfo: Decodable {
                let name: String
                let supportedGenerationMethods: [String]?
            }
            let models: [ModelInfo]?
        }

        struct GeminiCandidateResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable {
                        let text: String?
                        let thought: Bool?
                    }
                    let parts: [Part]?
                }
                let content: Content?
            }
            let candidates: [Candidate]?
        }

        struct GeminiApiErrorResponse: Decodable {
            struct ApiError: Decodable {
                let code: Int?
                let message: String?
                let status: String?
            }
            let error: ApiError?
        }

        do {
            // 1. Hämta aktiva modeller dynamiskt från Google (precis som i webbtestet), med gemini-3.8-flash som primär standard
            var candidateModels = ["gemini-3.8-flash", "gemini-3.7-flash", "gemini-2.5-flash"]

            if let listURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(encodedKey)") {
                var listReq = URLRequest(url: listURL)
                listReq.timeoutInterval = 8
                if let (listData, listResp) = try? await URLSession.shared.data(for: listReq),
                   let httpResp = listResp as? HTTPURLResponse {
                    if !(200...299).contains(httpResp.statusCode) {
                        if let errObj = try? JSONDecoder().decode(GeminiApiErrorResponse.self, from: listData),
                           let msg = errObj.error?.message, !msg.isEmpty {
                            if msg.localizedCaseInsensitiveContains("API key") || httpResp.statusCode == 400 || httpResp.statusCode == 403 {
                                throw NSError(
                                    domain: "Gemini",
                                    code: httpResp.statusCode,
                                    userInfo: [NSLocalizedDescriptionKey: "Ogiltig API-nyckel (\(msg))"]
                                )
                            }
                        }
                    } else if let decodedList = try? JSONDecoder().decode(GeminiModelsListResponse.self, from: listData),
                              let rawModels = decodedList.models {
                        let excludedKeywords = ["tts", "audio", "embed", "imagen", "aqa", "learnlm", "vision", "robotics", "computer-use"]
                        let supported = rawModels
                            .filter { ($0.supportedGenerationMethods ?? []).contains("generateContent") }
                            .map { $0.name.replacingOccurrences(of: "^models/", with: "", options: .regularExpression) }
                            .filter { name in
                                let lower = name.lowercased()
                                return !excludedKeywords.contains(where: { lower.contains($0) })
                            }

                        let flashModels = supported
                            .filter { $0.lowercased().contains("flash") }
                            .sorted { extractGeminiVersion($0) > extractGeminiVersion($1) }

                        let otherModels = supported
                            .filter { !$0.lowercased().contains("flash") }
                            .sorted { extractGeminiVersion($0) > extractGeminiVersion($1) }

                        var unique: [String] = []
                        for m in (flashModels + otherModels) where !unique.contains(m) {
                            unique.append(m)
                        }
                        if !unique.isEmpty {
                            candidateModels = Array(unique.prefix(4))
                        }
                    }
                }
            }

            // 2. Anropa kandidatmodellerna i tur och ordning med thinkingBudget: 0 (och 400-fallback utan thinkingConfig)
            var lastError: Error? = nil
            var parsedTemplateItems: [GameWalkthroughTemplateItem] = []
            var parsedSummary = "Kapitellista genererad för \(title)."
            var parsedProgressionType = "chapters"
            var usedModelName = candidateModels.first ?? "gemini-3.8-flash"

            for modelName in candidateModels {
                guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(encodedKey)") else {
                    continue
                }

                let payloadWithThinking: [String: Any] = [
                    "contents": [
                        ["parts": [["text": prompt]]]
                    ],
                    "generationConfig": [
                        "temperature": 0.1,
                        "responseMimeType": "application/json",
                        "maxOutputTokens": 8192,
                        "thinkingConfig": ["thinkingBudget": 0]
                    ]
                ]

                let payloadWithoutThinking: [String: Any] = [
                    "contents": [
                        ["parts": [["text": prompt]]]
                    ],
                    "generationConfig": [
                        "temperature": 0.1,
                        "responseMimeType": "application/json",
                        "maxOutputTokens": 8192
                    ]
                ]

                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 45
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: payloadWithThinking)

                    var (data, response) = try await URLSession.shared.data(for: request)
                    guard var http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }

                    // Om modellen inte stödjer thinkingConfig (HTTP 400), prova direkt utan thinkingConfig
                    if http.statusCode == 400 {
                        var retryRequest = URLRequest(url: url)
                        retryRequest.httpMethod = "POST"
                        retryRequest.timeoutInterval = 45
                        retryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        retryRequest.httpBody = try JSONSerialization.data(withJSONObject: payloadWithoutThinking)

                        let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                        if let retryHttp = retryResponse as? HTTPURLResponse {
                            data = retryData
                            http = retryHttp
                        }
                    }

                    if !(200...299).contains(http.statusCode) {
                        if let errResp = try? JSONDecoder().decode(GeminiApiErrorResponse.self, from: data),
                           let msg = errResp.error?.message, !msg.isEmpty {
                            if msg.localizedCaseInsensitiveContains("API key") {
                                throw NSError(
                                    domain: "GeminiKeyError",
                                    code: http.statusCode,
                                    userInfo: [NSLocalizedDescriptionKey: "Ogiltig API-nyckel. Kontrollera din nyckel från Google AI Studio."]
                                )
                            }
                            throw NSError(domain: "GeminiModelError", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
                        }
                        throw NSError(domain: "GeminiModelError", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
                    }

                    let geminiResp = try JSONDecoder().decode(GeminiCandidateResponse.self, from: data)
                    let parts = geminiResp.candidates?.first?.content?.parts ?? []
                    let nonThoughtText = parts
                        .filter { $0.thought != true }
                        .compactMap(\.text)
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let fallbackText = parts
                        .compactMap(\.text)
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let textContent = !nonThoughtText.isEmpty ? nonThoughtText : fallbackText

                    guard !textContent.isEmpty else {
                        throw NSError(domain: "GeminiModelError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tomt svar från AI"])
                    }

                    var cleaned = textContent
                    if let regex = try? NSRegularExpression(pattern: "```(?:json)?\\s*([\\s\\S]*?)\\s*```", options: [.caseInsensitive]),
                       let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned)),
                       match.numberOfRanges > 1,
                       let range = Range(match.range(at: 1), in: cleaned) {
                        cleaned = String(cleaned[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if let firstBrace = cleaned.firstIndex(of: "{"),
                              let lastBrace = cleaned.lastIndex(of: "}"),
                              firstBrace < lastBrace {
                        cleaned = String(cleaned[firstBrace...lastBrace]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    guard let jsonData = cleaned.data(using: .utf8),
                          let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                        throw NSError(domain: "GeminiModelError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Kunde inte tolka JSON från AI"])
                    }

                    let rawItems = (jsonObject["items"] as? [[String: Any]])
                        ?? (jsonObject["chapters"] as? [[String: Any]])
                        ?? (jsonObject["walkthrough"] as? [[String: Any]])
                        ?? (jsonObject["steps"] as? [[String: Any]])
                        ?? []

                    guard !rawItems.isEmpty else {
                        throw NSError(domain: "GeminiModelError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Inga kapitel returnerades"])
                    }

                    if let summary = jsonObject["summary"] as? String, !summary.isEmpty {
                        parsedSummary = summary
                    }
                    if let progType = jsonObject["progressionType"] as? String, !progType.isEmpty, progType != "none" {
                        parsedProgressionType = progType
                    }

                    parsedTemplateItems = rawItems.enumerated().compactMap { idx, dict in
                        let rawTitle = (dict["title"] as? String) ?? (dict["name"] as? String) ?? ""
                        let cleanTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanTitle.isEmpty else { return nil }

                        let orderVal: Int
                        if let intOrder = dict["order"] as? Int {
                            orderVal = intOrder
                        } else if let strOrder = dict["order"] as? String, let parsedInt = Int(strOrder) {
                            orderVal = parsedInt
                        } else {
                            orderVal = idx + 1
                        }

                        let groupVal = (dict["chapterGroup"] as? String)
                            ?? (dict["act"] as? String)
                            ?? (dict["region"] as? String)
                            ?? "Huvudberättelsen"

                        let descVal = dict["description"] as? String
                        let optionalVal = (dict["isOptional"] as? Bool) ?? false

                        return GameWalkthroughTemplateItem(
                            id: UUID().uuidString,
                            title: cleanTitle,
                            order: orderVal,
                            chapterGroup: groupVal,
                            description: descVal,
                            isOptional: optionalVal
                        )
                    }

                    if !parsedTemplateItems.isEmpty {
                        usedModelName = modelName
                        break
                    }
                } catch {
                    lastError = error
                    if let nsErr = error as NSError?, nsErr.domain == "GeminiKeyError" {
                        throw error
                    }
                    // Annars fortsätt till nästa reservmodell i candidateModels
                }
            }

            guard !parsedTemplateItems.isEmpty else {
                if let err = lastError {
                    throw err
                }
                throw URLError(.cannotParseResponse)
            }

            let ignSlug = title
                .folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            let ignSourceUrl = "https://www.ign.com/wikis/\(ignSlug)/Walkthrough"

            let template = GameWalkthroughTemplate(
                igdbId: targetIgdbId,
                title: game.title,
                normalizedTitle: GameWalkthroughTemplate.normalizeTitle(game.title),
                alternateIgdbIds: nil,
                hasLinearProgression: true,
                progressionType: parsedProgressionType,
                summary: parsedSummary,
                items: parsedTemplateItems,
                source: "AI (\(usedModelName))",
                sourceUrl: ignSourceUrl
            )

            var copy = game
            copy.todos = template.toTodoItems() + personalGoals
            syncProgress(for: &copy)
            onUpdateGame(copy)

            _ = try? await SupabaseSyncService.shared.upsertWalkthroughTemplate(template)
        } catch {
            aiErrorMessage = "Kunde inte hämta lista med AI (\(error.localizedDescription))."
        }
    }
}
