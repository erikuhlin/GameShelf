//
//  NewsListView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//

import SwiftUI

// MARK: - Hero Nyhetskort för Toppnyheten
struct NewsHeroCard: View {
    let item: NewsItem
    var onOpen: (URL) -> Void
    var onFindIGDB: (String) -> Void

    var body: some View {
        Button {
            if let u = item.link { onOpen(u) }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if let imgURL = item.image {
                        AsyncImage(url: imgURL) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .clipped()
                            default:
                                Color(.tertiarySystemFill)
                                    .frame(height: 180)
                            }
                        }
                    } else {
                        Color(.tertiarySystemFill)
                            .frame(height: 180)
                            .overlay(
                                Image(systemName: "newspaper.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary.opacity(0.5))
                            )
                    }

                    // Tagg
                    HStack {
                        Label(item.kind.localizedName, systemImage: item.kind.icon)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.primary)

                        Spacer()

                        if let matched = item.matchedGameTitle {
                            HStack(spacing: 4) {
                                Image(systemName: "gamecontroller.fill")
                                Text(matched)
                                    .lineLimit(1)
                            }
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.85), in: Capsule())
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(item.source)
                            .font(.caption.bold())
                            .foregroundStyle(.red)

                        if !item.relativePublishedTime.isEmpty {
                            Text("• \(item.relativePublishedTime)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Artikelrad för Nyhetslistan
struct ArticleRow: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                if let url = item.image {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                        default:
                            Color(.tertiarySystemFill)
                        }
                    }
                } else {
                    Color(.tertiarySystemFill)
                        .overlay(
                            Image(systemName: "newspaper")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Text(item.source)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    if !item.relativePublishedTime.isEmpty {
                        Text("• \(item.relativePublishedTime)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Label(item.kind.localizedName, systemImage: item.kind.icon)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)

                    if let matched = item.matchedGameTitle {
                        HStack(spacing: 3) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 8))
                            Text(matched)
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Helskärms-Nyhetslista
struct NewsListView: View {
    let items: [NewsItem]
    let canLoadMore: Bool
    let isLoadingMore: Bool
    let onOpen: (URL) -> Void
    let onFindIGDB: (String) -> Void
    let onLoadMore: () -> Void
    let initialPlatformRaw: String
    let initialKind: NewsKind?

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { a in
                    if let url = a.link {
                        Button { onOpen(url) } label: { ArticleRow(item: a) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { onFindIGDB(a.title) } label: {
                                    Label("Hitta i IGDB", systemImage: "magnifyingglass")
                                }
                                .tint(.red)
                            }
                            .contextMenu {
                                Button { onFindIGDB(a.title) } label: {
                                    Label("Hitta i IGDB", systemImage: "magnifyingglass")
                                }
                                Button { UIApplication.shared.open(url) } label: {
                                    Label("Öppna i Safari", systemImage: "safari")
                                }
                            }
                    } else {
                        ArticleRow(item: a)
                    }
                }

                if canLoadMore {
                    Button(action: onLoadMore) {
                        HStack(spacing: 8) {
                            if isLoadingMore { ProgressView().scaleEffect(0.9) }
                            Text(isLoadingMore ? "Laddar…" : "Visa fler nyheter")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Alla nyheter")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
