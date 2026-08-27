//
//  PlaytimeFilterSection.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

enum PlaytimeBracket: String, CaseIterable, Identifiable {
    case short = "< 5 tim"
    case medium = "5–15 tim"
    case long = "15–30 tim"
    case epic = "30+ tim"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .short: return "Korta pärlor du klarar på en kväll"
        case .medium: return "Fokuserade kampanjer och action"
        case .long: return "Djupare äventyr och berättelser"
        case .epic: return "Stora RPG & öppna världar"
        }
    }

    var icon: String {
        switch self {
        case .short: return "bolt.fill"
        case .medium: return "gamecontroller.fill"
        case .long: return "shield.fill"
        case .epic: return "crown.fill"
        }
    }

    func matches(hours: Int) -> Bool {
        switch self {
        case .short:
            return hours > 0 && hours < 5
        case .medium:
            return hours >= 5 && hours <= 15
        case .long:
            return hours > 15 && hours <= 30
        case .epic:
            return hours > 30
        }
    }
}

struct PlaytimeFilterSection: View {
    @EnvironmentObject var store: LibraryStore
    @State private var selectedBracket: PlaytimeBracket = .short

    private var matchingLocalGames: [Game] {
        store.games.filter { game in
            guard game.isOwned, let est = game.estimatedHours, est > 0 else { return false }
            return selectedBracket.matches(hours: est)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hur mycket tid har du?")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text(selectedBracket.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Tidschips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlaytimeBracket.allCases) { bracket in
                        let isSelected = selectedBracket == bracket
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedBracket = bracket
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: bracket.icon)
                                    .font(.caption2)
                                Text(bracket.rawValue)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.red : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            // Matchande spel från biblioteket
            if !matchingLocalGames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(matchingLocalGames) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ZStack(alignment: .topTrailing) {
                                        CoverView(title: game.title, url: game.coverURL, corner: 10, height: 130)
                                            .frame(width: 95, height: 130)
                                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                                        if let est = game.estimatedHours {
                                            Text("~\(est)h")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(.ultraThinMaterial, in: Capsule())
                                                .padding(6)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(game.title)
                                            .font(.caption.bold())
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        StatusBadge(status: game.status)
                                    }
                                    .frame(width: 95, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inga spel i biblioteket med denna speltid")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                        Text("Lägg till fler spel eller utforska genrerna nedan.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}
