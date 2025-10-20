//
//  RawgSearchViewModel.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-05.
//


import Foundation
import Combine
import SwiftUI

@MainActor
final class RawgSearchViewModel: ObservableObject {
    @Published var query: String = "" { didSet { onQueryChange() } }
    @Published var results: [RawgGame] = []
    @Published var isLoading = false
    @Published var hasMore = false
    @Published var errorMessage: String?

    private let api: RawgClient
    private var searchTask: Task<Void, Never>?
    private var page = 1

    /// injicera din lokala lista för "Added"-markering
    var localTitles: () -> [String] = { [] }

    init(api: RawgClient, localTitles: @escaping () -> [String] = { [] }) {
        self.api = api
        self.localTitles = localTitles
    }

    func onQueryChange() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reset and cancel if empty or too short
        guard q.count >= 2 else {
            results = []
            hasMore = false
            page = 1
            isLoading = false
            searchTask?.cancel()
            return
        }

        // Debounce + cancel previous
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms
                try Task.checkCancellation()
                await self.performSearch(reset: true)
            } catch is CancellationError {
                await MainActor.run { self.isLoading = false }
            } catch {
                // ignore other errors here; performSearch handles errors
            }
        }
    }

    func loadMoreIfNeeded() {
        guard hasMore, !isLoading, !query.isEmpty else { return }
        Task { await performSearch(reset: false) }
    }

    func reset() {
        searchTask?.cancel()
        query = ""
        results = []
        hasMore = false
        isLoading = false
        page = 1
    }

    private func performSearch(reset: Bool) async {
        isLoading = true
        if reset { page = 1 }
        do {
            let res = try await api.search(query, page: page)
            if reset { results = res.items } else { results += res.items }
            hasMore = res.hasMore
            page += 1
        } catch {
            if reset { results = [] }
            hasMore = false
            errorMessage = "Kunde inte söka på RAWG."
        }
        isLoading = false
    }

    func isAlreadyAdded(_ item: RawgGame) -> Bool {
        let norm = normalize(item.name)
        return localTitles().map(normalize).contains(norm)
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "™", with: "")
            .replacingOccurrences(of: "®", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
