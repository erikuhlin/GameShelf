import SwiftUI

public struct GameRatingsDetailSheet: View {
    public let gameTitle: String
    public let communityRating: Double?
    public let communityVotes: Int?
    public let criticRating: Double?
    public let criticReviewsCount: Int?
    public let steamSummary: SteamQuerySummary?
    public let steamAppID: String?
    public let userRating: Int?
    public let metacriticData: MetacriticGameData?
    public let currentPlatform: String?
    
    @Environment(\.dismiss) private var dismiss
    
    public init(
        gameTitle: String,
        communityRating: Double?,
        communityVotes: Int?,
        criticRating: Double?,
        criticReviewsCount: Int?,
        steamSummary: SteamQuerySummary?,
        steamAppID: String?,
        userRating: Int?,
        metacriticData: MetacriticGameData? = nil,
        currentPlatform: String? = nil
    ) {
        self.gameTitle = gameTitle
        self.communityRating = communityRating
        self.communityVotes = communityVotes
        self.criticRating = criticRating
        self.criticReviewsCount = criticReviewsCount
        self.steamSummary = steamSummary
        self.steamAppID = steamAppID
        self.userRating = userRating
        self.metacriticData = metacriticData
        self.currentPlatform = currentPlatform
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Metacritic (om det finns)
                    if let mc = metacriticData, let score = mc.metascore, score > 0 {
                        metacriticCard(mc)
                    }
                    
                    // 2. Steam Spelaromdömen
                    if let steam = steamSummary, (steam.totalReviews ?? 0) > 0 {
                        steamRatingCard(steam)
                    }
                    
                    // 3. IGDB Community
                    if let cRating = communityRating {
                        igdbCommunityCard(rating: cRating, votes: communityVotes)
                    }
                    
                    // 4. IGDB Kritikerbetyg
                    if let cr = criticRating {
                        criticRatingCard(rating: cr, count: criticReviewsCount)
                    }
                    
                    // 5. Ditt eget betyg
                    if let ur = userRating, ur > 0 {
                        userRatingCard(ur)
                    }
                    
                    // Om inga betyg finns alls
                    if (metacriticData?.metascore == nil || (metacriticData?.metascore ?? 0) == 0) &&
                        steamSummary == nil && communityRating == nil && criticRating == nil && (userRating == nil || userRating == 0) {
                        VStack(spacing: 8) {
                            Image(systemName: "star.slash")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("Inga betyg registrerade ännu för detta spel.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 32)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Betyg & Recensioner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
    
    // MARK: - Metacritic Card
    private func metacriticCard(_ mc: MetacriticGameData) -> some View {
        let preferredScore = mc.score(forPlatform: currentPlatform) ?? mc.metascore ?? 0
        let color: Color = preferredScore >= 75 ? .green : (preferredScore >= 50 ? .yellow : .red)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("M")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("Metacritic Metascore")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                if mc.mustPlay == true {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                        Text("Must-Play")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.yellow.opacity(0.15), in: Capsule())
                } else {
                    Text("Kritikerbetyg")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(spacing: 4) {
                    Text("\(preferredScore)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text("/ 100")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let sentiment = mc.sentiment, !sentiment.isEmpty {
                        Text(sentiment)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                    } else {
                        Text("Metascore")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                    }
                    
                    if let count = mc.reviewCount, count > 0 {
                        Text("Baserat på \(formatNumber(count)) professionella recensioner")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Aggregerat branschsnitt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Plattformsöversikt om det finns fler än 1 plattform med betyg
            if let plats = mc.platforms, plats.filter({ ($0.score ?? 0) > 0 }).count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Betyg per plattform")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    ForEach(plats.filter { ($0.score ?? 0) > 0 }) { p in
                        let pScore = p.score ?? 0
                        let pColor: Color = pScore >= 75 ? .green : (pScore >= 50 ? .yellow : .red)
                        let isUsersPlatform: Bool = {
                            guard let cur = currentPlatform?.lowercased() else { return false }
                            return p.name.lowercased().contains(cur) || cur.contains(p.name.lowercased())
                        }()
                        
                        HStack(spacing: 8) {
                            Text("\(pScore)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(minWidth: 26)
                                .padding(.vertical, 2)
                                .background(pColor)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            
                            Text(p.name)
                                .font(.caption.weight(isUsersPlatform ? .bold : .regular))
                                .foregroundStyle(.primary)
                            
                            if isUsersPlatform {
                                Text("Din plattform")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color(.tertiarySystemFill), in: Capsule())
                            }
                            
                            Spacer()
                            
                            if let rc = p.reviewCount, rc > 0 {
                                Text("\(rc) rec.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isUsersPlatform ? Color.primary.opacity(0.04) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.top, 4)
            }
            
            if let urlStr = mc.url, let url = URL(string: urlStr) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text("Läs alla recensioner på Metacritic")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Steam Card
    private func steamRatingCard(_ steam: SteamQuerySummary) -> some View {
        let percent = steam.positivePercent
        let color: Color = percent >= 70 ? .blue : (percent >= 40 ? .orange : .red)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundStyle(.cyan)
                    Text("Steam Spelaromdömen")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Text("Verifierade spelare")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                    Text("\(percent)%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(steam.localizedScoreDesc)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Baserat på \(steam.formattedTotalReviews)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Fördelningsstapel
            if let total = steam.totalReviews, total > 0, let pos = steam.totalPositive, let neg = steam.totalNegative {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.blue)
                                .frame(width: max(4, geo.size.width * CGFloat(pos) / CGFloat(total)))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.red.opacity(0.8))
                        }
                    }
                    .frame(height: 6)
                    
                    HStack {
                        Text("\(formatNumber(pos)) positiva (\(percent)%)")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Spacer()
                        Text("\(formatNumber(neg)) negativa (\(100 - percent)%)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if let appID = steamAppID, let url = URL(string: "https://store.steampowered.com/app/\(appID)") {
                Link(destination: url) {
                    HStack {
                        Text("Öppna i Steam Store")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.cyan)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - IGDB Community Card
    private func igdbCommunityCard(rating: Double, votes: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("IGDB Community")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Text("Spelarcommunity")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(spacing: 2) {
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                    Text("/ 10")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let v = votes, v > 0 {
                        Text("Baserat på \(formatNumber(v)) röster")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                    } else {
                        Text("Communitybetyg")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                    }
                    Text("Samlat spelargenomsnitt från IGDB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Varning om litet underlag (< 5 spelarröster)
            if let v = votes, v < 5 {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(v > 0
                        ? "Litet röstunderlag: Betyget är baserat på endast \(v) spelarröst\(v == 1 ? "" : "er") på IGDB och kan därför vara missvisande."
                        : "Litet röstunderlag: Mycket få spelarröster registrerade på IGDB.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Critic Rating Card
    private func criticRatingCard(rating: Double, count: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.blue)
                    Text("Kritikerbetyg")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Text("Spelpressen")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(spacing: 2) {
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                    Text("/ 10")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let c = count, c > 0 {
                        Text("Baserat på \(formatNumber(c)) professionella recensioner")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                    } else {
                        Text("Spelpressens genomsnitt")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                    }
                    Text("Aggregerade betyg från speltidningar och sajter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Info om få kritikerrecensioner (< 3 recensioner)
            if let c = count, c < 3 {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text(c > 0
                        ? "Få recensioner: Endast \(c) kritikerrecension\(c == 1 ? "" : "er") registrerade på IGDB."
                        : "Få recensioner: Mycket få kritikerrecensioner registrerade på IGDB.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - User Rating Card
    private func userRatingCard(_ rating: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ditt personliga betyg")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("Sparat i ditt Gameshelf-bibliotek")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 2) {
                Text("\(rating)")
                    .font(.title.bold())
                    .foregroundStyle(.yellow)
                Text("/ 10")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
}
