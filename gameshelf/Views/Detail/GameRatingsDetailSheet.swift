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
    
    @Environment(\.dismiss) private var dismiss
    
    public init(
        gameTitle: String,
        communityRating: Double?,
        communityVotes: Int?,
        criticRating: Double?,
        criticReviewsCount: Int?,
        steamSummary: SteamQuerySummary?,
        steamAppID: String?,
        userRating: Int?
    ) {
        self.gameTitle = gameTitle
        self.communityRating = communityRating
        self.communityVotes = communityVotes
        self.criticRating = criticRating
        self.criticReviewsCount = criticReviewsCount
        self.steamSummary = steamSummary
        self.steamAppID = steamAppID
        self.userRating = userRating
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Steam Spelaromdömen
                    if let steam = steamSummary, (steam.totalReviews ?? 0) > 0 {
                        steamRatingCard(steam)
                    }
                    
                    // 2. IGDB Community
                    if let cRating = communityRating {
                        igdbCommunityCard(rating: cRating, votes: communityVotes)
                    }
                    
                    // 3. Kritikerbetyg
                    if let cr = criticRating {
                        criticRatingCard(rating: cr, count: criticReviewsCount)
                    }
                    
                    // 4. Ditt eget betyg
                    if let ur = userRating, ur > 0 {
                        userRatingCard(ur)
                    }
                    
                    // Om inga betyg finns alls
                    if steamSummary == nil && communityRating == nil && criticRating == nil && (userRating == nil || userRating == 0) {
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
