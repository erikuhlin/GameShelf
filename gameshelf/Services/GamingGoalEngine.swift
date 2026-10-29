//
//  GamingGoalEngine.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-10-24.
//

import SwiftUI

struct GameGoalProgressInfo: Sendable, Hashable {
    let percentage: Int
    let completedTasks: Int
    let totalTasks: Int
    let remainingTasks: Int
    let nextTaskTitle: String?
    let displaySubtext: String
    let hasTasks: Bool
}

struct GameGoalTempoInfo: Sendable, Hashable {
    let daysRemainingInYear: Int
    let remainingGames: Int
    let daysPerGame: Int?
    let isGoalReached: Bool
    let isAheadOfPace: Bool
    let isUnrealistic: Bool
    let displayText: String
}

struct GameGoalBadge: Identifiable, Sendable, Hashable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let isUnlocked: Bool
    let progressRatio: Double
}

enum GamingGoalEngine {
    static var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    static func completedGames(in games: [Game], for year: Int = currentYear) -> [Game] {
        games.filter { g in
            guard g.isOwned, g.status == .completed, !g.isMultiplayerOrOngoing else { return false }
            if let y = g.completedYear {
                return y == year
            }
            return false
        }
        .sorted { (g1, g2) -> Bool in
            let d1 = g1.completedDate ?? Date.distantPast
            let d2 = g2.completedDate ?? Date.distantPast
            return d1 > d2
        }
    }

    static func completedCount(in games: [Game], for year: Int = currentYear) -> Int {
        completedGames(in: games, for: year).count
    }

    static func abandonedGames(in games: [Game], for year: Int = currentYear) -> [Game] {
        games.filter { g in
            guard g.isOwned, g.status == .abandoned else { return false }
            if let y = g.completedYear {
                return y == year
            }
            return false
        }
        .sorted { (g1, g2) -> Bool in
            let d1 = g1.completedDate ?? Date.distantPast
            let d2 = g2.completedDate ?? Date.distantPast
            return d1 > d2
        }
    }

    static func abandonedCount(in games: [Game], for year: Int = currentYear) -> Int {
        abandonedGames(in: games, for: year).count
    }

    static func formatShortDayMonth(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "d MMM"
        return df.string(from: date).replacingOccurrences(of: ".", with: "").lowercased()
    }

    /// Fokusmål hålls helt isär från status (endast valda targetIDs, exklusive klarade/avslutade spel, max 3)
    static func focusGames(from allGames: [Game], targetIDs: [String] = []) -> [Game] {
        guard !targetIDs.isEmpty else { return [] }
        let lookup: [String: Game] = Dictionary(
            allGames.map { ($0.id.uuidString.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var result: [Game] = []
        var seenIDs = Set<UUID>()
        for id in targetIDs {
            if let game = lookup[id.lowercased()],
               game.status != .completed,
               game.status != .abandoned,
               seenIDs.insert(game.id).inserted {
                result.append(game)
                if result.count == 3 { break }
            }
        }
        return result
    }

    static func calculateProgress(for game: Game) -> GameGoalProgressInfo {
        let tasks = game.todos
        if !tasks.isEmpty {
            let total = tasks.count
            let done = tasks.filter(\.isDone).count
            let remaining = max(0, total - done)
            let pct = total > 0 ? Int(round((Double(done) / Double(total)) * 100)) : 0

            let next = tasks
                .filter { !$0.isDone }
                .sorted(by: { ($0.order ?? 0) < ($1.order ?? 0) })
                .first?
                .title

            let statusLabel: String = {
                switch game.status {
                case .playing: return "Spelar nu"
                case .paused: return "Pausat"
                case .notStarted: return "Backlog"
                case .completed: return "Klarat"
                case .abandoned: return "Avslutat"
                }
            }()

            var subParts: [String] = [
                statusLabel,
                "\(done) av \(total) uppdrag"
            ]
            if let n = next, !n.isEmpty {
                subParts.append("Nästa: \(n)")
            }

            return GameGoalProgressInfo(
                percentage: pct,
                completedTasks: done,
                totalTasks: total,
                remainingTasks: remaining,
                nextTaskTitle: next,
                displaySubtext: subParts.joined(separator: " · "),
                hasTasks: true
            )
        }

        // Fallback om inga todos är definierade
        let statusLabel: String = {
            switch game.status {
            case .playing: return "Spelar nu"
            case .paused: return "Pausat"
            case .notStarted: return "Backlog"
            case .completed: return "Klarat"
            case .abandoned: return "Avslutat"
            }
        }()

        var subParts: [String] = [statusLabel]
        if let est = game.estimatedHours, est > 0 {
            subParts.append("~ \(est) tim")
        } else if game.status == .playing {
            subParts.append("Lägg till uppdrag")
        }

        let fallbackPct: Int = {
            if game.status == .completed { return 100 }
            if let sp = game.storyProgress {
                switch sp {
                case .justStarted: return 15
                case .midway: return 50
                case .nearEnd: return 85
                case .completed: return 100
                }
            }
            return 0
        }()

        return GameGoalProgressInfo(
            percentage: fallbackPct,
            completedTasks: 0,
            totalTasks: 0,
            remainingTasks: 0,
            nextTaskTitle: nil,
            displaySubtext: subParts.joined(separator: " · "),
            hasTasks: false
        )
    }

    static func calculateTempo(goal: Int, completed: Int, targetYear: Int = currentYear) -> GameGoalTempoInfo {
        let calendar = Calendar.current
        let now = Date()

        // Sista sekunden på året
        var endComponents = DateComponents()
        endComponents.year = targetYear
        endComponents.month = 12
        endComponents.day = 31
        endComponents.hour = 23
        endComponents.minute = 59
        endComponents.second = 59
        let endOfYear = calendar.date(from: endComponents) ?? now

        let daysRemaining = max(1, calendar.dateComponents([.day], from: now, to: endOfYear).day ?? 1)
        let remainingGames = max(0, goal - completed)

        if remainingGames == 0 {
            return GameGoalTempoInfo(
                daysRemainingInYear: daysRemaining,
                remainingGames: 0,
                daysPerGame: nil,
                isGoalReached: true,
                isAheadOfPace: true,
                isUnrealistic: false,
                displayText: "Årsmålet för \(targetYear) är nått!"
            )
        }

        let daysPerGame = max(1, daysRemaining / remainingGames)
        let isUnrealistic = daysPerGame < 7

        // Beräkna om man ligger före schema
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let totalDaysInYear = calendar.range(of: .day, in: .year, for: now)?.count ?? 365
        let expectedCompleted = (Double(dayOfYear) / Double(totalDaysInYear)) * Double(goal)
        let isAhead = Double(completed) >= expectedCompleted

        let text = "\(daysRemaining) dagar kvar · ca ett spel var \(daysPerGame):e dag för att nå målet"

        return GameGoalTempoInfo(
            daysRemainingInYear: daysRemaining,
            remainingGames: remainingGames,
            daysPerGame: daysPerGame,
            isGoalReached: false,
            isAheadOfPace: isAhead,
            isUnrealistic: isUnrealistic,
            displayText: text
        )
    }

    static func closestToFinish(from games: [Game]) -> (game: Game, info: GameGoalProgressInfo)? {
        let active = games.filter { $0.status != .completed && $0.status != .abandoned }
        guard !active.isEmpty else { return nil }

        var candidates: [(game: Game, info: GameGoalProgressInfo)] = []
        for g in active {
            let info = calculateProgress(for: g)
            // Minst 50% eller högst 5 uppdrag kvar (om uppdrag finns)
            let qualifiesByTasks = info.hasTasks && info.totalTasks > 0 && (info.remainingTasks <= 5 || info.percentage >= 50)
            let qualifiesByPct = !info.hasTasks && info.percentage >= 50

            if qualifiesByTasks || qualifiesByPct {
                candidates.append((g, info))
            }
        }

        // Välj den med högst procent eller minst kvarstående uppdrag
        return candidates.max(by: { a, b in
            if a.info.hasTasks && b.info.hasTasks {
                if a.info.remainingTasks != b.info.remainingTasks {
                    return a.info.remainingTasks > b.info.remainingTasks // Lägre remaining är bättre
                }
            }
            return a.info.percentage < b.info.percentage
        })
    }

    static func badges(goal: Int, completed: Int, targetYear: Int = currentYear) -> [GameGoalBadge] {
        let safeGoal = max(1, goal)
        let halfGoal = max(1, Int(ceil(Double(safeGoal) / 2.0)))

        return [
            GameGoalBadge(
                id: "first_game",
                icon: "sparkles",
                title: "Första segern",
                subtitle: "Klara ditt allra första spel för året",
                isUnlocked: completed >= 1,
                progressRatio: min(1.0, Double(completed) / 1.0)
            ),
            GameGoalBadge(
                id: "halfway",
                icon: "flag.checkered",
                title: "Halvvägs dit",
                subtitle: "Klara \(halfGoal) av \(safeGoal) spel mot årsmålet",
                isUnlocked: completed >= halfGoal,
                progressRatio: min(1.0, Double(completed) / Double(halfGoal))
            ),
            GameGoalBadge(
                id: "goal_completed",
                icon: "trophy.fill",
                title: "Mästare \(targetYear)",
                subtitle: "Nå hela årsmålet på \(safeGoal) klarade spel",
                isUnlocked: completed >= safeGoal,
                progressRatio: min(1.0, Double(completed) / Double(safeGoal))
            )
        ]
    }
}
