//
//  PriceWatcherService.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-09-11.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Game Deal Model
struct GameDealInfo: Codable, Hashable, Sendable {
    let gameTitle: String
    let isOnSale: Bool
    let salePrice: Double
    let normalPrice: Double
    let savingsPercent: Double
    let storeID: String
    let storeName: String
    let dealID: String
    let steamAppID: String?
    let dealURL: URL?
    let cheapestPriceEver: Double?
    let isHistoricalLow: Bool
    let fetchedAt: Date

    var formattedSalePrice: String {
        String(format: "$%.2f", salePrice)
    }

    var formattedNormalPrice: String {
        String(format: "$%.2f", normalPrice)
    }

    var savingsFormatted: String {
        let rounded = Int(savingsPercent.rounded())
        return "-\(rounded)%"
    }
}

// MARK: - Store Quick Link Model
struct StoreQuickLink: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let platformCategory: String
    let iconSystemName: String
    let url: URL
    let accentColor: Color
}

// MARK: - CheapShark Raw DTOs
private struct CheapSharkDealDTO: Decodable {
    let title: String?
    let dealID: String?
    let storeID: String?
    let gameID: String?
    let salePrice: String?
    let normalPrice: String?
    let isOnSale: String?
    let savings: String?
    let steamAppID: String?
}

private struct CheapSharkGameLookupDTO: Decodable {
    struct CheapestPriceEverDTO: Decodable {
        let price: String?
        let date: Int?
    }
    let cheapestPriceEver: CheapestPriceEverDTO?
}

// MARK: - Service
@MainActor
final class PriceWatcherService: ObservableObject {
    static let shared = PriceWatcherService()

    @Published private(set) var deals: [String: GameDealInfo] = [:]
    @Published private(set) var isLoading: Bool = false

    private let cacheKey = "gameshelf_cached_deals_v2"
    private let cacheTTL: TimeInterval = 4 * 3600 // 4 timmar
    private var inFlightQueries = Set<String>()

    private init() {
        loadCachedDeals()
    }

    // MARK: - Public API

    /// Hämta aktiv deal för ett visst spel
    func deal(for game: Game) -> GameDealInfo? {
        let key = normalizeTitle(game.title)
        return deals[key]
    }

    /// Hämta aktiva deals för en lista av spel (körs asynkront och sparsamt)
    func fetchDeals(for games: [Game]) async {
        let now = Date()
        let neededGames = games.filter { game in
            let key = normalizeTitle(game.title)
            if inFlightQueries.contains(key) { return false }
            if let existing = deals[key], now.timeIntervalSince(existing.fetchedAt) < cacheTTL {
                return false
            }
            return true
        }

        guard !neededGames.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        // Max 3 anrop parallellt för att inte överbelasta nätverket
        let batchSize = 3
        for chunk in neededGames.chunked(into: batchSize) {
            await withTaskGroup(of: (String, GameDealInfo?).self) { group in
                for game in chunk {
                    let key = normalizeTitle(game.title)
                    inFlightQueries.insert(key)
                    group.addTask {
                        let deal = await self.queryDeal(for: game.title)
                        return (key, deal)
                    }
                }

                for await (key, dealInfo) in group {
                    inFlightQueries.remove(key)
                    if let deal = dealInfo {
                        deals[key] = deal
                    }
                }
            }
        }

        saveCachedDeals()
    }

    /// Generera smarta direktlänkar till respektive butik baserat på spelets plattformar
    func storeLinks(for game: Game) -> [StoreQuickLink] {
        var links: [StoreQuickLink] = []
        let titleEncoded = game.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let platformsLower = game.platforms.map { $0.lowercased() }

        // Kolla PlayStation
        let hasPlayStation = platformsLower.contains(where: {
            $0.contains("playstation") || $0.contains("ps4") || $0.contains("ps5") || $0.contains("ps3")
        })
        if hasPlayStation {
            if let url = URL(string: "https://store.playstation.com/sv-se/search/\(titleEncoded)") {
                links.append(StoreQuickLink(
                    name: "PlayStation Store",
                    platformCategory: "PlayStation",
                    iconSystemName: "playstation.logo",
                    url: url,
                    accentColor: .blue
                ))
            }
        }

        // Kolla Nintendo Switch
        let hasNintendo = platformsLower.contains(where: {
            $0.contains("switch") || $0.contains("nintendo")
        })
        if hasNintendo {
            if let url = URL(string: "https://store.nintendo.se/sv/search?q=\(titleEncoded)") {
                links.append(StoreQuickLink(
                    name: "Nintendo eShop",
                    platformCategory: "Nintendo",
                    iconSystemName: "gamecontroller.fill",
                    url: url,
                    accentColor: .red
                ))
            }
        }

        // Kolla Xbox
        let hasXbox = platformsLower.contains(where: {
            $0.contains("xbox") || $0.contains("series x") || $0.contains("series s") || $0.contains("one")
        })
        if hasXbox {
            if let url = URL(string: "https://www.xbox.com/sv-SE/games/store/search?q=\(titleEncoded)") {
                links.append(StoreQuickLink(
                    name: "Xbox Store",
                    platformCategory: "Xbox",
                    iconSystemName: "x.circle.fill",
                    url: url,
                    accentColor: .green
                ))
            }
        }

        // Kolla PC / Steam
        let hasPC = platformsLower.contains(where: {
            $0.contains("pc") || $0.contains("windows") || $0.contains("steam") || $0.contains("mac")
        }) || platformsLower.isEmpty // Fallback till Steam om plattform ej specad
        if hasPC {
            let steamURLString: String
            if let deal = self.deal(for: game), let steamAppID = deal.steamAppID, !steamAppID.isEmpty {
                steamURLString = "https://store.steampowered.com/app/\(steamAppID)"
            } else {
                steamURLString = "https://store.steampowered.com/search/?term=\(titleEncoded)"
            }
            if let url = URL(string: steamURLString) {
                links.append(StoreQuickLink(
                    name: "Steam Store",
                    platformCategory: "PC",
                    iconSystemName: "desktopcomputer",
                    url: url,
                    accentColor: .cyan
                ))
            }
        }

        return links
    }

    // MARK: - Intern CheapShark Query

    private nonisolated func queryDeal(for title: String) async -> GameDealInfo? {
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.cheapshark.com/api/1.0/deals?title=\(encoded)&exact=1") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("GameshelfApp/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            var dealsList = try JSONDecoder().decode([CheapSharkDealDTO].self, from: data)

            // Om exact=1 inte gav något, prova utan exact
            if dealsList.isEmpty {
                if let fallbackURL = URL(string: "https://www.cheapshark.com/api/1.0/deals?title=\(encoded)&pageSize=3") {
                    var fallbackReq = URLRequest(url: fallbackURL)
                    fallbackReq.setValue("GameshelfApp/1.0", forHTTPHeaderField: "User-Agent")
                    fallbackReq.timeoutInterval = 8.0
                    if let (fbData, fbResp) = try? await URLSession.shared.data(for: fallbackReq),
                       (fbResp as? HTTPURLResponse)?.statusCode == 200 {
                        dealsList = (try? JSONDecoder().decode([CheapSharkDealDTO].self, from: fbData)) ?? []
                    }
                }
            }

            guard let best = dealsList.first(where: { ($0.isOnSale ?? "0") == "1" }) ?? dealsList.first else {
                return nil
            }

            let sPrice = Double(best.salePrice ?? "0") ?? 0.0
            let nPrice = Double(best.normalPrice ?? "0") ?? 0.0
            let savPct = Double(best.savings ?? "0") ?? 0.0
            let onSale = (best.isOnSale ?? "0") == "1" && savPct > 0.0
            let stID = best.storeID ?? "1"
            let stName = storeName(for: stID)

            var dealRedirectURL: URL? = nil
            // Om det är Steam och vi har steamAppID, länka direkt till Steam!
            if stID == "1", let appID = best.steamAppID, !appID.isEmpty {
                dealRedirectURL = URL(string: "https://store.steampowered.com/app/\(appID)")
            } else if let dID = best.dealID, !dID.isEmpty {
                // VIKTIGT: dID från CheapShark API är redan URL-kodad (t.ex. %2F, %2B, %3D).
                // Genom att inte köra addingPercentEncoding undviks dubbelkodning (%25)
                // som fick CheapShark att misslyckas och omdirigera till sin startsida.
                dealRedirectURL = URL(string: "https://www.cheapshark.com/redirect?dealID=\(dID)")
            }

            // Hämta historiskt lägsta pris om gameID finns
            var histLow: Double? = nil
            var isAllTimeLow = false
            if let gID = best.gameID,
               let lookupURL = URL(string: "https://www.cheapshark.com/api/1.0/games?id=\(gID)") {
                var lookupReq = URLRequest(url: lookupURL)
                lookupReq.setValue("GameshelfApp/1.0", forHTTPHeaderField: "User-Agent")
                lookupReq.timeoutInterval = 5.0
                if let (lookupData, lookupResp) = try? await URLSession.shared.data(for: lookupReq),
                   (lookupResp as? HTTPURLResponse)?.statusCode == 200,
                   let lookupResult = try? JSONDecoder().decode(CheapSharkGameLookupDTO.self, from: lookupData),
                   let lowStr = lookupResult.cheapestPriceEver?.price,
                   let lowVal = Double(lowStr) {
                    histLow = lowVal
                    if onSale && sPrice <= (lowVal + 0.05) {
                        isAllTimeLow = true
                    }
                }
            }

            return GameDealInfo(
                gameTitle: best.title ?? title,
                isOnSale: onSale,
                salePrice: sPrice,
                normalPrice: nPrice,
                savingsPercent: savPct,
                storeID: stID,
                storeName: stName,
                dealID: best.dealID ?? "",
                steamAppID: best.steamAppID,
                dealURL: dealRedirectURL,
                cheapestPriceEver: histLow,
                isHistoricalLow: isAllTimeLow,
                fetchedAt: Date()
            )
        } catch {
            return nil
        }
    }

    private nonisolated func storeName(for storeID: String) -> String {
        switch storeID {
        case "1": return "Steam"
        case "2": return "GamersGate"
        case "3": return "GreenManGaming"
        case "4": return "Amazon"
        case "5": return "GameStop"
        case "6": return "Direct2Drive"
        case "7": return "GOG"
        case "8": return "EA / Origin"
        case "9": return "Get Games"
        case "10": return "Shiny Loot"
        case "11": return "Humble Store"
        case "12": return "Desura"
        case "13": return "Ubisoft Store"
        case "14": return "IndieGameStand"
        case "15": return "Fanatical"
        case "16": return "Gamesrocket"
        case "17": return "Games Republic"
        case "18": return "SilaGames"
        case "19": return "Playfield"
        case "20": return "ImperialGames"
        case "21": return "WinGameStore"
        case "22": return "FunStock"
        case "23": return "GameBillet"
        case "24": return "Voidu"
        case "25": return "Epic Games Store"
        case "26": return "Razer Game Store"
        case "27": return "Gamesplanet"
        case "28": return "Gamesload"
        case "29": return "2Game"
        case "30": return "IndieGala"
        case "31": return "Blizzard Shop"
        case "32": return "AllYouPlay"
        case "33": return "DLGamer"
        case "34": return "Noctre"
        case "35": return "DreamGame"
        default: return "PC Store"
        }
    }

    private nonisolated func normalizeTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Lokal Caching
    private func loadCachedDeals() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: GameDealInfo].self, from: data) else {
            return
        }
        let now = Date()
        // Behåll endast cache som inte är äldre än 24h
        self.deals = decoded.filter { now.timeIntervalSince($0.value.fetchedAt) < 24 * 3600 }
    }

    private func saveCachedDeals() {
        if let data = try? JSONEncoder().encode(deals) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}

// MARK: - Helper för batching
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
