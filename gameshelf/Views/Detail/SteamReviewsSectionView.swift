import SwiftUI

public struct SteamReviewsSectionView: View {
    public let summary: SteamQuerySummary?
    public let reviews: [SteamReviewItem]?
    public let steamAppID: String
    public let isLoading: Bool
    
    @State private var expandedReviewIDs: Set<String> = []
    
    public init(
        summary: SteamQuerySummary?,
        reviews: [SteamReviewItem]?,
        steamAppID: String,
        isLoading: Bool = false
    ) {
        self.summary = summary
        self.reviews = reviews
        self.steamAppID = steamAppID
        self.isLoading = isLoading
    }
    
    private var steamURL: URL? {
        URL(string: "https://store.steampowered.com/app/\(steamAppID)")
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header med titel och diskret Steam-märkning
            HStack {
                Text("Spelaromdömen")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.cyan)
                    Text("Steam")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(.tertiarySystemFill), in: Capsule())
            }
            
            if isLoading && summary == nil {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Hämtar omdömen från Steam...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if let summary = summary, (summary.totalReviews ?? 0) > 0 {
                // Sammanfattningskort
                summaryView(summary)
                
                // Utvalda hjälpsamma omdömen
                if let reviews = reviews, !reviews.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mest hjälpsamma omdömen")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        
                        ForEach(reviews.prefix(2)) { review in
                            reviewCard(review)
                        }
                    }
                }
                
                // Länk till Steam för alla recensioner
                if let url = steamURL {
                    Link(destination: url) {
                        HStack {
                            Text("Läs alla omdömen på Steam")
                                .font(.footnote.weight(.semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.cyan)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Inga spelaromdömen registrerade ännu.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Sammanfattning
    private func summaryView(_ summary: SteamQuerySummary) -> some View {
        let percent = summary.positivePercent
        let color: Color = {
            if percent >= 70 { return .blue }
            if percent >= 40 { return .orange }
            return .red
        }()
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                // Stor procentsiffra
                HStack(spacing: 3) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.subheadline)
                        .foregroundStyle(color)
                    Text("\(percent)%")
                        .font(.title2.bold())
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.localizedScoreDesc)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text("Baserat på \(summary.formattedTotalReviews)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Subtil fördelningsstapel
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(6, geo.size.width * CGFloat(percent) / 100.0), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(Color(.tertiarySystemFill).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - Enskilt omdömeskort
    private func reviewCard(_ review: SteamReviewItem) -> some View {
        let isExpanded = expandedReviewIDs.contains(review.id)
        let cleaned = review.cleanedReview
        let isLong = cleaned.count > 240
        
        return VStack(alignment: .leading, spacing: 6) {
            // Header med rekommendation & speltid
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: review.votedUp ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(review.votedUp ? .green : .red)
                    Text(review.votedUp ? "Rekommenderas" : "Rekommenderas inte")
                        .font(.caption2.bold())
                        .foregroundStyle(review.votedUp ? .green : .red)
                }
                
                if let playtime = review.author?.formattedPlaytime {
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(playtime)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let votes = review.votesUp, votes > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9))
                        Text("\(votes)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            
            // Text med "Visa mer"
            Text(cleaned)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(isExpanded ? nil : 4)
                .lineSpacing(2)
            
            if isLong {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedReviewIDs.remove(review.id)
                        } else {
                            expandedReviewIDs.insert(review.id)
                        }
                    }
                } label: {
                    Text(isExpanded ? "Visa mindre" : "Visa mer")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
