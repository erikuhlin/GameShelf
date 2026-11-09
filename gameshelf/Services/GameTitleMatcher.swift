//
//  GameTitleMatcher.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-11-09.
//

import Foundation

/// Strikt och robust matchning av speltitlar mot externa tjänster (Steam, Metacritic, CheapShark etc.)
/// Förhindrar att uppföljare, föregångare eller orelaterade spel felaktigt matchas
/// (t.ex. att GTA VI matchar GTA Vice City eller GTA V).
public enum GameTitleMatcher: Sendable {
    
    private static let romanNumeralMap: [String: String] = [
        "I": "1", "II": "2", "III": "3", "IV": "4", "V": "5",
        "VI": "6", "VII": "7", "VIII": "8", "IX": "9", "X": "10",
        "XI": "11", "XII": "12", "XIII": "13", "XIV": "14", "XV": "15",
        "XVI": "16", "XVII": "17", "XVIII": "18", "XIX": "19", "XX": "20",
        "XXI": "21", "XXII": "22", "XXIII": "23", "XXIV": "24", "XXV": "25",
        "XXVI": "26", "XXVII": "27", "XXVIII": "28", "XXIX": "29", "XXX": "30"
    ]
    
    private static let recognizedEditionWords: Set<String> = [
        "edition", "definitive", "remastered", "remake", "enhanced", "deluxe",
        "special", "gold", "goty", "game", "year", "complete", "anniversary",
        "bundle", "directors", "cut", "vr", "standard", "collector", "collectors",
        "premium", "ultimate", "hd", "the", "of", "and", "original", "intergrade"
    ]
    
    private static let badWords: Set<String> = [
        "soundtrack", "season pass", "dlc", "content", "artbook", "ost"
    ]
    
    /// Kontrollerar om `candidateTitle` (från Steam, Metacritic etc.) matchar `gameTitle`.
    public nonisolated static func isMatch(gameTitle: String, candidateTitle: String) -> Bool {
        let t1 = tokenize(gameTitle)
        let t2 = tokenize(candidateTitle)
        
        guard !t1.isEmpty, !t2.isEmpty else { return false }
        if t1 == t2 { return true }
        
        let lowerCandidate = candidateTitle.lowercased()
        let lowerGame = gameTitle.lowercased()
        
        // Förkasta om kandidaten är ett soundtrack/dlc men inte själva spelet
        for bad in badWords {
            if lowerCandidate.contains(bad) && !lowerGame.contains(bad) {
                return false
            }
        }
        
        // Sekvensnummer (t.ex. 6 i "GTA 6" / "GTA VI", 5 i "GTA V")
        let numbers1 = t1.filter { isSequenceNumber($0) }
        let numbers2 = t2.filter { isSequenceNumber($0) }
        
        // Om sekvensnumren skiljer sig (t.ex. GTA VI vs GTA Vice City, eller GTA 6 vs GTA 5) -> förkasta!
        if numbers1 != numbers2 {
            return false
        }
        
        // Om kandidaten börjar med hela speltiteln
        if t2.count >= t1.count {
            let prefixMatches = zip(t1, t2).allSatisfy { $0 == $1 }
            if prefixMatches {
                let remainder = t2.dropFirst(t1.count)
                // Resten måste uteslutande bestå av godkända utgåveord (t.ex. "The Definitive Edition", "GOTY")
                if remainder.allSatisfy({ recognizedEditionWords.contains($0) }) {
                    return true
                }
            }
        }
        
        // Om speltiteln är längre än kandidaten (t.ex. spelet heter "The Witcher 3: Wild Hunt GOTY", kandidaten "The Witcher 3: Wild Hunt")
        if t1.count > t2.count {
            let prefixMatches = zip(t2, t1).allSatisfy { $0 == $1 }
            if prefixMatches {
                let remainder = t1.dropFirst(t2.count)
                if remainder.allSatisfy({ recognizedEditionWords.contains($0) }) {
                    return true
                }
            }
        }
        
        return false
    }
    
    public nonisolated static func tokenize(_ title: String) -> [String] {
        // Normalisera accenter (t.ex. ö -> o, é -> e)
        let folded = title.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        
        return folded
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "–", with: " ")
            .replacingOccurrences(of: "—", with: " ")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "™", with: "")
            .replacingOccurrences(of: "®", with: "")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: "[", with: " ")
            .replacingOccurrences(of: "]", with: " ")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { token in
                let upper = token.uppercased()
                if let mappedNum = romanNumeralMap[upper] {
                    return mappedNum
                }
                return token
            }
    }
    
    private nonisolated static func isSequenceNumber(_ token: String) -> Bool {
        guard let num = Int(token) else { return false }
        // Årtal (1970–2040) betraktas inte som sekvensnummer
        if num >= 1970 && num <= 2040 {
            return false
        }
        return true
    }
}
