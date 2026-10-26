//
//  GameCard.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI

// MARK: - GameCard Badge
enum GameCardBadge: Equatable {
    case playStatus(PlayStatus, isMultiplayerOrOngoing: Bool = false)
    case custom(text: String, color: Color = Color(hex: "#FF9500"), icon: String? = nil)
    case rank(Int)
    case goal

    var text: String {
        switch self {
        case .playStatus(let status, let isMulti):
            return status.title(isMultiplayerOrOngoing: isMulti)
        case .custom(let text, _, _):
            return text
        case .rank(let rank):
            return "#\(rank)"
        case .goal:
            return "Mål"
        }
    }

    var color: Color {
        switch self {
        case .playStatus(let status, _):
            return status == .playing ? Color(hex: "#34C759") : (status == .paused ? Color(hex: "#FF9500") : status.color)
        case .custom(_, let color, _):
            return color
        case .rank(let rank):
            switch rank {
            case 1: return Color(hex: "#F9A825")
            case 2: return Color(hex: "#E0E0E0")
            case 3: return Color(hex: "#CD7F32")
            default: return Color(hex: "#B3B3B3")
            }
        case .goal:
            return Color(hex: "#FF9500")
        }
    }

    var icon: String? {
        switch self {
        case .playStatus(let status, let isMulti):
            return status.icon(isMultiplayerOrOngoing: isMulti)
        case .custom(_, _, let icon):
            return icon
        case .rank(let rank):
            return rank <= 3 ? "trophy.fill" : nil
        case .goal:
            return nil
        }
    }
}

// MARK: - GameCard Metric
enum GameCardMetric: Equatable {
    case rating(Double)
    case stars(Int)
    case hype(Int)
    case text(String, color: Color = .textSecondary)
}

// MARK: - GameCard Style
enum GameCardStyle: Equatable {
    case standard
    case libraryGrid
}

// MARK: - GameCard Status Badge Configuration
struct GameCardStatusBadgeConfig: Equatable {
    let icon: String
    let color: Color

    static func from(game: Game) -> GameCardStatusBadgeConfig {
        if game.status == .playing {
            return GameCardStatusBadgeConfig(icon: "play.fill", color: Color(hex: "#34C759"))
        } else if game.status == .completed {
            return GameCardStatusBadgeConfig(icon: "checkmark", color: Color(hex: "#00C7BE"))
        } else if game.status == .paused {
            return GameCardStatusBadgeConfig(icon: "pause.fill", color: Color(hex: "#FF9500"))
        } else if game.status == .abandoned {
            return GameCardStatusBadgeConfig(icon: "flag.checkered", color: Color(hex: "#AF52DE"))
        } else if game.isBacklog {
            return GameCardStatusBadgeConfig(icon: "archivebox.fill", color: Color(hex: "#007AFF"))
        } else if !game.isOwned {
            return GameCardStatusBadgeConfig(icon: "heart.fill", color: Color(hex: "#FF2D55"))
        } else {
            return GameCardStatusBadgeConfig(icon: "circle", color: Color(hex: "#8E8E93"))
        }
    }
}

// MARK: - Unified GameCard Component
struct GameCard: View {
    let title: String
    let subtitle: String?
    let imageURL: URL?
    var badge: GameCardBadge? = nil
    var metric: GameCardMetric? = nil

    // Sizing & Appearance
    var width: CGFloat = 136
    var coverHeight: CGFloat = 176
    var cornerRadius: CGFloat = 16

    // Library Grid & Unified Properties
    var style: GameCardStyle = .standard
    var platform: String? = nil
    var ratingValue: Double? = nil
    var ratingText: String? = nil
    var statusBadgeConfig: GameCardStatusBadgeConfig? = nil
    var showWishlistInfo: Bool = false
    var deal: GameDealInfo? = nil
    var pausedProgressRatio: Double? = nil

    static func shortPlatform(from platforms: [String]) -> String {
        guard let first = platforms.first, !first.isEmpty else {
            return "-"
        }
        let lower = first.lowercased()
        if lower.contains("playstation 5") || lower == "ps5" { return "PS5" }
        if lower.contains("playstation 4") || lower == "ps4" { return "PS4" }
        if lower.contains("playstation 3") || lower == "ps3" { return "PS3" }
        if lower.contains("playstation") { return "PS" }
        if lower.contains("switch") || lower.contains("nintendo") { return "Switch" }
        if lower.contains("series x") || lower.contains("series s") || lower.contains("xbox series") { return "XSX" }
        if lower.contains("xbox one") { return "XOne" }
        if lower.contains("xbox") { return "Xbox" }
        if lower.contains("pc") || lower.contains("windows") { return "PC" }
        if lower.contains("mac") { return "Mac" }
        if lower.contains("ios") || lower.contains("iphone") || lower.contains("ipad") { return "iOS" }
        if lower.contains("android") { return "Android" }
        return first.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(
        title: String,
        subtitle: String? = nil,
        imageURL: URL? = nil,
        badge: GameCardBadge? = nil,
        metric: GameCardMetric? = nil,
        width: CGFloat = 136,
        coverHeight: CGFloat = 176,
        cornerRadius: CGFloat = 16,
        style: GameCardStyle = .standard,
        platform: String? = nil,
        ratingValue: Double? = nil,
        ratingText: String? = nil,
        statusBadgeConfig: GameCardStatusBadgeConfig? = nil,
        showWishlistInfo: Bool = false,
        deal: GameDealInfo? = nil,
        pausedProgressRatio: Double? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.badge = badge
        self.metric = metric
        self.width = width
        self.coverHeight = coverHeight
        self.cornerRadius = cornerRadius
        self.style = style
        self.platform = platform
        self.ratingValue = ratingValue
        self.ratingText = ratingText
        self.statusBadgeConfig = statusBadgeConfig
        self.showWishlistInfo = showWishlistInfo
        self.deal = deal
        self.pausedProgressRatio = pausedProgressRatio
    }

    // Convenience Init from standard Game model
    init(
        game: Game,
        style: GameCardStyle = .standard,
        showWishlistInfo: Bool = false,
        width: CGFloat = 136,
        coverHeight: CGFloat = 176,
        cornerRadius: CGFloat = 16
    ) {
        self.style = style
        self.showWishlistInfo = showWishlistInfo
        self.title = game.title
        var meta: [String] = []
        if let platform = game.platforms.first { meta.append(platform) }
        if game.releaseYear > 0 { meta.append("\(game.releaseYear)") }
        self.subtitle = meta.joined(separator: " • ")
        self.imageURL = game.coverURL
        self.badge = .playStatus(game.status, isMultiplayerOrOngoing: game.isMultiplayerOrOngoing)
        if let r = game.rating, r > 0 {
            self.metric = .rating(Double(r))
            self.ratingValue = Double(r)
        } else if let igdb = Game.normalizeIgdbRating(game.igdbRating), igdb > 0 {
            self.metric = .rating(igdb)
            self.ratingValue = igdb
        } else {
            self.metric = nil
            self.ratingValue = nil
        }
        self.platform = GameCard.shortPlatform(from: game.platforms)
        self.statusBadgeConfig = GameCardStatusBadgeConfig.from(game: game)
        self.deal = PriceWatcherService.shared.deal(for: game)
        if game.status == .paused && !game.isMultiplayerOrOngoing {
            let progressInfo = GamingGoalEngine.calculateProgress(for: game)
            if progressInfo.hasTasks && progressInfo.percentage > 0 {
                self.pausedProgressRatio = min(max(Double(progressInfo.percentage) / 100.0, 0.0), 1.0)
            } else {
                self.pausedProgressRatio = nil
            }
        } else {
            self.pausedProgressRatio = nil
        }
        self.width = width
        self.coverHeight = coverHeight
        self.cornerRadius = cornerRadius
    }

    // Convenience Init from IGDBGame
    init(
        igdbGame: IGDBGame,
        badge: GameCardBadge? = nil,
        metric: GameCardMetric? = nil,
        width: CGFloat = 136,
        coverHeight: CGFloat = 176,
        cornerRadius: CGFloat = 16,
        platform: String? = nil
    ) {
        self.title = igdbGame.name
        var meta: [String] = []
        if let genre = igdbGame.genres?.first?.name {
            meta.append(genre.replacingOccurrences(of: "Role-playing (RPG)", with: "RPG"))
        }
        if let y = igdbGame.releaseYear { meta.append("\(y)") }
        self.subtitle = meta.joined(separator: " • ")
        self.imageURL = igdbGame.coverURL
        self.badge = badge
        if let m = metric {
            self.metric = m
        } else if let tr = igdbGame.totalRating, tr > 0 {
            self.metric = .rating(tr / 10.0)
        } else if let ar = igdbGame.aggregatedRating, ar > 0 {
            self.metric = .rating(ar / 10.0)
        } else if let h = igdbGame.hypes, h > 0 {
            self.metric = .hype(h)
        } else {
            self.metric = nil
        }
        if let m = self.metric, case .rating(let val) = m {
            self.ratingValue = val
        }
        self.width = width
        self.coverHeight = coverHeight
        self.cornerRadius = cornerRadius
        if let p = platform {
            self.platform = p
        } else if let resolved = PlatformMatcher.resolvePlatforms(availableIGDBPlatforms: igdbGame.platforms?.map(\.name) ?? []).first {
            self.platform = PlatformMatcher.shortName(resolved)
        } else {
            self.platform = nil
        }
    }

    // Convenience Init from ToplistGameItem
    init(
        toplistItem: ToplistGameItem,
        rank: Int? = nil,
        width: CGFloat = 136,
        coverHeight: CGFloat = 176,
        cornerRadius: CGFloat = 16
    ) {
        self.title = toplistItem.title
        var meta: [String] = []
        if let y = toplistItem.release_year { meta.append("\(y)") }
        self.subtitle = meta.joined(separator: " • ")
        self.imageURL = toplistItem.coverURL
        if let rank = rank {
            self.badge = .rank(rank)
        } else {
            self.badge = nil
        }
        if let score = toplistItem.weighted_score ?? toplistItem.total_rating, score > 0 {
            let val = score / 10.0
            self.metric = .rating(val)
            self.ratingValue = val
        } else {
            self.metric = nil
            self.ratingValue = nil
        }
        self.width = width
        self.coverHeight = coverHeight
        self.cornerRadius = cornerRadius
    }

    // Convenience Init from TrendingItem
    init(
        trendingItem: TrendingItem,
        width: CGFloat = 136,
        coverHeight: CGFloat = 176,
        cornerRadius: CGFloat = 16
    ) {
        self.title = trendingItem.title
        self.subtitle = trendingItem.platformText
        self.imageURL = trendingItem.image
        if let b = trendingItem.badgeText, !b.isEmpty {
            self.badge = .custom(text: b, color: Color(hex: "#FF9500"))
        } else {
            self.badge = nil
        }
        if trendingItem.rating > 0 {
            self.metric = .rating(trendingItem.rating)
            self.ratingValue = trendingItem.rating
        } else {
            self.metric = nil
            self.ratingValue = nil
        }
        self.width = width
        self.coverHeight = coverHeight
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        if style == .libraryGrid {
            libraryGridCardBody
        } else {
            standardCardBody
        }
    }

    // MARK: - Library Grid Card Body (3-Column Grid)
    private var libraryGridCardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Poster Cover Section (4:5 Aspect Ratio)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .aspectRatio(4.0 / 5.0, contentMode: .fit)
                    .overlay(
                        GeometryReader { geo in
                            ZStack {
                                Color(hex: "#2C2C2E")

                                if let url = imageURL {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: geo.size.width, height: geo.size.height)
                                                .clipped()
                                        case .failure:
                                            placeholderFallback
                                        case .empty:
                                            Color(hex: "#2C2C2E")
                                                .overlay(
                                                    ProgressView()
                                                        .controlSize(.small)
                                                        .tint(Color.brandRed)
                                                )
                                        @unknown default:
                                            placeholderFallback
                                        }
                                    }
                                } else {
                                    placeholderFallback
                                }

                                // Tunn 3.5 px progressbar längst ned på omslaget för pausade spel med progress > 0 %
                                if let ratio = pausedProgressRatio, ratio > 0 {
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.black.opacity(0.45))
                                            .frame(width: geo.size.width, height: 3.5)

                                        Rectangle()
                                            .fill(Color(hex: "#FF9500").opacity(0.88))
                                            .frame(
                                                width: max(4, min(geo.size.width, geo.size.width * ratio)),
                                                height: 3.5
                                            )
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                }
                            }
                        }
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 16,
                            style: .continuous
                        )
                    )

                // Minimal Icon-based StatusBadge (Top-Left: top 6, leading 6, 24x24 pt)
                if let badgeConfig = statusBadgeConfig {
                    ZStack {
                        Circle()
                            .fill(Color.neutralBackground.opacity(0.8))
                            .background(.ultraThinMaterial, in: Circle())
                        Image(systemName: badgeConfig.icon)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(badgeConfig.color)
                    }
                    .frame(width: 24, height: 24)
                    .padding([.top, .leading], 6)
                }

                // Wishlist Sale Badge (Top-Right: top 6, trailing 6)
                if showWishlistInfo, let deal = deal, deal.isOnSale {
                    HStack(spacing: 2) {
                        Text("🔥")
                            .font(.system(size: 7.5))
                        Text(deal.savingsFormatted)
                            .font(.system(size: 8.5, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                    .shadow(color: .red.opacity(0.4), radius: 3, x: 0, y: 1)
                    .padding([.top, .trailing], 6)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                }
            }

            // 2. Card Body (Integrated Surface #1C1C1E, padding 8)
            VStack(alignment: .leading, spacing: 6) {
                // Title: Primary white text (#FFFFFF), 11 pt Bold, line height ~14 pt, lineLimit(2), minHeight: 28 pt
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineSpacing(1)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .topLeading)

                // Top separator: Subtle 1 pt border/divider with Color.white.opacity(0.05)
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)

                // Inline Footer Row (Space-between)
                HStack(alignment: .center, spacing: 4) {
                    // Leading: Platform text in Color.textSecondary (#B3B3B3), 10 pt Regular
                    Text(platform ?? "-")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    // Trailing: Rating (e.g. "★ 8.5") in Color.feedbackWarning (#F9A825), 10 pt Bold. If none, "-"
                    if let rating = displayRating {
                        HStack(spacing: 2.5) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.yellow)
                            Text(rating)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.feedbackWarning)
                        }
                        .lineLimit(1)
                    } else {
                        Text("-")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(height: 14)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 71, maxHeight: 71, alignment: .topLeading)
            .background(Color.neutralSurface)
        }
        .background(Color.neutralSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(platform ?? "")")
    }

    private var displayRating: String? {
        if let ratingText = ratingText {
            return ratingText
        }
        if let val = ratingValue, val > 0 {
            let norm = Game.normalizeIgdbRating(val) ?? val
            if norm.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(norm))"
            } else {
                return String(format: "%.1f", norm)
            }
        }
        if let metric = metric, case .rating(let val) = metric, val > 0 {
            let norm = Game.normalizeIgdbRating(val) ?? val
            if norm.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(norm))"
            } else {
                return String(format: "%.1f", norm)
            }
        }
        return nil
    }

    // MARK: - Standard Card Body (Explore Carousels)
    private var standardCardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Poster Cover Section
            coverSection
                .frame(width: width, height: coverHeight)

            // Card Body (Integrated Surface Variant)
            VStack(alignment: .leading, spacing: 3) {
                // Title
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34, alignment: .topLeading)

                // Metadata
                Text(subtitle ?? " ")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 14, maxHeight: 14, alignment: .leading)

                // Footer Metric
                footerMetricView
                    .padding(.top, 2)
            }
            .padding(10)
            .frame(width: width, height: 92, alignment: .topLeading)
            .background(Color.neutralSurface)
        }
        .frame(width: width, height: coverHeight + 92)
        .background(Color.neutralSurface)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle ?? "")")
    }

    // MARK: - Cover Section
    private var coverSection: some View {
        ZStack(alignment: .topLeading) {
            // Dark Placeholder & Image
            ZStack {
                Color(hex: "#2C2C2E")

                if let url = imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholderFallback
                        case .empty:
                            Color(hex: "#2C2C2E")
                                .overlay(
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(Color.brandRed)
                                )
                        @unknown default:
                            placeholderFallback
                        }
                    }
                } else {
                    placeholderFallback
                }
            }
            .frame(width: width, height: coverHeight)
            .clipped()

            // Badge Overlay (Top-Left)
            if let badge = badge {
                badgeView(badge)
                    .padding(8)
            }
        }
    }

    private var placeholderFallback: some View {
        Color(hex: "#2C2C2E")
            .overlay(
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.white.opacity(0.2))
            )
    }

    // MARK: - Badge View
    @ViewBuilder
    private func badgeView(_ badge: GameCardBadge) -> some View {
        HStack(spacing: 4.5) {
            if let icon = badge.icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(badge.color)
            } else if case .playStatus(let status, _) = badge, status == .playing {
                Circle()
                    .fill(badge.color)
                    .frame(width: 5.5, height: 5.5)
            }

            Text(badge.text)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            ZStack {
                Capsule()
                    .fill(Color(hex: "#101012").opacity(0.88))
                Capsule()
                    .fill(badge.color.opacity(0.15))
            }
        )
        .overlay(
            Capsule()
                .stroke(badge.color.opacity(0.60), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.40), radius: 3, x: 0, y: 1.5)
    }

    // MARK: - Footer Metric View
    @ViewBuilder
    private var footerMetricView: some View {
        if let metric = metric {
            HStack(spacing: 3) {
                switch metric {
                case .rating(let val):
                    let norm = Game.normalizeIgdbRating(val) ?? val
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(norm.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(norm))" : String(format: "%.1f", norm))
                        .font(.system(size: 12, weight: .bold))
                case .stars(let stars):
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: i < stars ? "star.fill" : "star")
                            .font(.system(size: 9))
                    }
                case .hype(let count):
                    Text("🔥")
                        .font(.system(size: 10))
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                case .text(let txt, let color):
                    Text(txt)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(color)
                }
            }
            .foregroundStyle(metricColor(metric))
            .frame(height: 16, alignment: .leading)
        } else {
            Color.clear
                .frame(height: 16)
        }
    }

    private func metricColor(_ metric: GameCardMetric) -> Color {
        switch metric {
        case .rating, .stars:
            return Color.feedbackWarning
        case .hype:
            return Color(hex: "#FF9500")
        case .text(_, let color):
            return color
        }
    }
}
