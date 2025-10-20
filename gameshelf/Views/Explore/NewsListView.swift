//
//  NewsListView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//

import SwiftUI

private enum NewsPlatformFilter: String, CaseIterable { case all = "All", playstation = "PlayStation", xbox = "Xbox", nintendo = "Nintendo", pc = "PC", mobile = "Mobile" }
private func keywords(for filter: NewsPlatformFilter) -> [String] {
    switch filter {
    case .all: return []
    case .playstation: return ["ps5", "playstation"]
    case .xbox: return ["xbox", "series x", "series s"]
    case .nintendo: return ["switch", "nintendo"]
    case .pc: return ["pc", "steam"]
    case .mobile: return ["iphone", "android", "mobile"]
    }
}
private func applyPlatform(_ items: [NewsItem], filter: NewsPlatformFilter) -> [NewsItem] {
    let keys = keywords(for: filter)
    guard !keys.isEmpty else { return items }
    return items.filter { it in
        let t = it.title.lowercased()
        return keys.contains(where: { t.contains($0) })
    }
}
private func applyKind(_ items: [NewsItem], kind: NewsKind?) -> [NewsItem] {
    guard let kind = kind else { return items }
    return items.filter { $0.kind == kind }
}

struct ArticleRow: View {
    let item: NewsItem
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                if let url = item.image {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Color.clear
                        }
                    }
                    .clipped()
                } else {
                    Image(systemName: "newspaper").imageScale(.large)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).lineLimit(3)
                HStack(spacing: 4) {
                    Text(item.source)
                    if let d = item.published { Text("· \(relative(d))") }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                // Kind chip
                HStack {
                    Text(item.kind.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    Spacer(minLength: 0)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.ds.surface))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }
}

private func relative(_ date: Date) -> String {
    let r = RelativeDateTimeFormatter()
    r.unitsStyle = .short
    return r.localizedString(for: date, relativeTo: Date())
}

struct NewsListView: View {
    let items: [NewsItem]
    let canLoadMore: Bool
    let isLoadingMore: Bool
    let onOpen: (URL) -> Void
    let onFindRawg: (String) -> Void
    let onLoadMore: () -> Void
    let initialPlatformRaw: String
    let initialKind: NewsKind?

    @State private var platformFilter: NewsPlatformFilter = .all
    @State private var kindFilter: NewsKind? = nil

    init(items: [NewsItem],
         canLoadMore: Bool,
         isLoadingMore: Bool,
         onOpen: @escaping (URL) -> Void,
         onFindRawg: @escaping (String) -> Void,
         onLoadMore: @escaping () -> Void,
         initialPlatformRaw: String,
         initialKind: NewsKind?) {
        self.items = items
        self.canLoadMore = canLoadMore
        self.isLoadingMore = isLoadingMore
        self.onOpen = onOpen
        self.onFindRawg = onFindRawg
        self.onLoadMore = onLoadMore
        self.initialPlatformRaw = initialPlatformRaw
        self.initialKind = initialKind
        if let pf = NewsPlatformFilter(rawValue: initialPlatformRaw) {
            _platformFilter = State(initialValue: pf)
        } else {
            _platformFilter = State(initialValue: .all)
        }
        _kindFilter = State(initialValue: initialKind)
    }

    private var filtered: [NewsItem] {
        applyKind(applyPlatform(items, filter: platformFilter), kind: kindFilter)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { a in
                    if let url = a.link {
                        Button { onOpen(url) } label: { ArticleRow(item: a) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { onFindRawg(a.title) } label: {
                                    Label("Find on RAWG", systemImage: "magnifyingglass")
                                }
                                .tint(.ds.brandRed)
                            }
                            .contextMenu {
                                Button { onFindRawg(a.title) } label: {
                                    Label("Find on RAWG", systemImage: "magnifyingglass")
                                }
                                Button { UIApplication.shared.open(url) } label: {
                                    Label("Open in Safari", systemImage: "safari")
                                }
                            }
                    } else {
                        HStack {
                            ArticleRow(item: a)
                            Button { onFindRawg(a.title) } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                if canLoadMore {
                    Button(action: onLoadMore) {
                        HStack(spacing: 8) {
                            if isLoadingMore { ProgressView().scaleEffect(0.9) }
                            Text(isLoadingMore ? "Loading…" : "See more")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.ds.brandRed)
                }
            }
            .navigationTitle("All news")
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(NewsPlatformFilter.allCases, id: \.self) { f in
                            Button(action: { platformFilter = f }) {
                                if platformFilter == f { Image(systemName: "checkmark") }
                                Text(f.rawValue)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }

                    Menu {
                        Button(action: { kindFilter = nil }) {
                            if kindFilter == nil { Image(systemName: "checkmark") }
                            Text("All types")
                        }
                        Divider()
                        ForEach([NewsKind.review, .preview, .guide, .opinion, .interview, .video, .deal, .feature, .news], id: \.self) { k in
                            Button(action: { kindFilter = k }) {
                                if kindFilter == k { Image(systemName: "checkmark") }
                                Text(k.rawValue.capitalized)
                            }
                        }
                    } label: {
                        Label("Type", systemImage: "line.3.horizontal.decrease")
                    }
                }
            }
            .refreshable {
                // här kan du koppla till reload om du vill
            }
        }
    }
}
