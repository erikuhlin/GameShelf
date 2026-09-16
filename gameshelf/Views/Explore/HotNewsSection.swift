//
//  HotNewsSection.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-09-15.
//

import SwiftUI

struct HotNewsSection: View {
    let items: [NewsItem]
    var isLoading: Bool = false
    var onSelect: (URL) -> Void = { _ in }
    var onFindIGDB: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.red)
                Text("Hetaste nyheterna just nu")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if isLoading && items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            skeletonCard
                        }
                    }
                }
            } else if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            HotNewsCard(
                                item: item,
                                onSelect: onSelect,
                                onFindIGDB: onFindIGDB
                            )
                        }
                    }
                }
            }
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 220, height: 120)
                .overlay(ProgressView().scaleEffect(0.7))

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.quaternarySystemFill))
                    .frame(width: 180, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.quaternarySystemFill))
                    .frame(width: 120, height: 12)
            }
        }
    }
}

struct HotNewsCard: View {
    let item: NewsItem
    var onSelect: (URL) -> Void
    var onFindIGDB: (String) -> Void

    var body: some View {
        Button {
            if let link = item.link {
                onSelect(link)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if let imgURL = item.image {
                        AsyncImage(url: imgURL) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .scaledToFill()
                                    .frame(width: 220, height: 120)
                                    .clipped()
                            default:
                                Color(.tertiarySystemFill)
                                    .frame(width: 220, height: 120)
                            }
                        }
                    } else {
                        Color(.tertiarySystemFill)
                            .frame(width: 220, height: 120)
                            .overlay(
                                Image(systemName: "newspaper.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary.opacity(0.5))
                            )
                    }

                    // Badgar ovanpå bilden
                    HStack {
                        Label(item.kind.localizedName, systemImage: item.kind.icon)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.primary)

                        Spacer()

                        if let matched = item.matchedGameTitle {
                            HStack(spacing: 3) {
                                Image(systemName: "gamecontroller.fill")
                                Text(matched)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.red.opacity(0.9), in: Capsule())
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(8)
                }
                .frame(width: 220, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Titel och metadata
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(height: 38, alignment: .topLeading)

                    HStack(spacing: 5) {
                        Text(item.source)
                            .font(.caption2.bold())
                            .foregroundStyle(.red)

                        if !item.relativePublishedTime.isEmpty {
                            Text("• \(item.relativePublishedTime)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(width: 220)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let link = item.link {
                Button {
                    UIApplication.shared.open(link)
                } label: {
                    Label("Öppna i Safari", systemImage: "safari")
                }
            }

            Button {
                onFindIGDB(item.title)
            } label: {
                Label("Hitta spel i IGDB", systemImage: "magnifyingglass")
            }

            if let link = item.link {
                ShareLink(item: link) {
                    Label("Dela artikel", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}
