//
//  CoverView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI

struct CoverView: View {
    let title: String
    let url: URL?
    var corner: CGFloat = Radius.m
    var height: CGFloat = 160

    enum FitMode { case fill, fit }
    var fitMode: FitMode = .fill

    // Ny: när true fyller bilden hela tillgängliga bredden (använder container-bredd i stället för 3:4)
    var fullWidth: Bool = false

    private var aspect: CGFloat { 3.0 / 4.0 }
    private var cornerShape: some InsettableShape {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
    }

    // Internal state for one-time retry from RAWG crop -> resize
    @State private var retryURL: URL? = nil
    @State private var hasRetried = false

    // Cache a normalized URL for this instance to avoid redoing logic
    @State private var normalizedURL: URL? = nil

    // Manual loading state
    @State private var phase: LoadPhase = .empty

    // Track in-flight request to avoid duplicate/cancel storms
    @State private var currentURLLoading: URL? = nil

    // Toggle to dump extra logs (only in DEBUG)
    #if DEBUG
    private let debugLogs = true
    #else
    private let debugLogs = false
    #endif

    var body: some View {
        Group {
            if fullWidth {
                GeometryReader { geo in
                    let width = geo.size.width
                    let sourceURL = retryURL ?? normalizedURL

                    ZStack {
                        cornerShape.fill(Color.ds.surface)

                        switch phase {
                        case .success(let image, let fromURL):
                            let isRawg = isRawgHost(fromURL)
                            let useFill: Bool = {
                                switch fitMode {
                                case .fill: return isRawg
                                case .fit:  return false
                                }
                            }()

                            Group {
                                if useFill {
                                    image.resizable().scaledToFill()
                                } else {
                                    image.resizable().scaledToFit()
                                }
                            }
                            .frame(width: width, height: height)
                            .clipped()
                            .clipShape(cornerShape)
                            .onAppear {
                                dbg("[CoverView] (fullWidth) success:", fromURL.absoluteString, "isRawg:", isRawg, "mode:", useFill ? "fill" : "fit")
                            }

                        case .failure(let error, let fromURL):
                            placeholder(width: width)
                                .onAppear {
                                    let code = (error as? URLError)?.errorCode ?? (error as NSError).code
                                    dbg("[CoverView] (fullWidth) failure:", error.localizedDescription, "(\(code)) for", fromURL.absoluteString)
                                }

                        case .loading(let fromURL):
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color.ds.brandRed)
                                .frame(width: width, height: height)
                                .onAppear {
                                    dbg("[CoverView] (fullWidth) loading for", fromURL.absoluteString)
                                }

                        case .empty:
                            placeholder(width: width)
                        }
                    }
                    .frame(width: width, height: height)
                    .contentShape(cornerShape)
                    .accessibilityLabel("Cover for \(title)")
                    .onAppear {
                        if normalizedURL == nil {
                            // För fullWidth, sikta på container-bredden med “safeWidth” bucket
                            let target = safeWidth(for: Int(width))
                            normalizedURL = buildNormalizedURL(from: url, targetWidth: target)
                            dbg("[CoverView] (fullWidth) normalizedURL:", normalizedURL?.absoluteString ?? "nil", "original:", url?.absoluteString ?? "nil")
                        }
                        if phase == .empty, let u = sourceURL, currentURLLoading != u {
                            Task { await startLoadingIfNeeded(u) }
                        }
                    }
                    .onChange(of: url) { _ in
                        retryURL = nil
                        hasRetried = false
                        normalizedURL = nil
                        phase = .empty
                        currentURLLoading = nil
                    }
                    .onChange(of: sourceURL) { newSource in
                        guard let u = newSource else { return }
                        Task { await startLoadingIfNeeded(u) }
                    }
                    .transaction { t in t.disablesAnimations = true }
                }
                .frame(height: height)
            } else {
                // Originalbeteende (oförändrat) – används överallt inkl. LibraryView
                let width = height * aspect
                let sourceURL = retryURL ?? normalizedURL

                ZStack {
                    cornerShape.fill(Color.ds.surface)

                    switch phase {
                    case .success(let image, let fromURL):
                        let isRawg = isRawgHost(fromURL)
                        let useFill: Bool = {
                            switch fitMode {
                            case .fill: return isRawg
                            case .fit:  return false
                            }
                        }()

                        Group {
                            if useFill {
                                image.resizable().scaledToFill()
                            } else {
                                image.resizable().scaledToFit()
                            }
                        }
                        .frame(width: width, height: height)
                        .clipped()
                        .clipShape(cornerShape)
                        .onAppear {
                            dbg("[CoverView] success:", fromURL.absoluteString, "isRawg:", isRawg, "mode:", useFill ? "fill" : "fit")
                        }

                    case .failure(let error, let fromURL):
                        placeholder(width: width)
                            .onAppear {
                                let code = (error as? URLError)?.errorCode ?? (error as NSError).code
                                dbg("[CoverView] failure:", error.localizedDescription, "(\(code)) for", fromURL.absoluteString)
                            }

                    case .loading(let fromURL):
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.ds.brandRed)
                            .frame(width: width, height: height)
                            .onAppear {
                                dbg("[CoverView] loading for", fromURL.absoluteString)
                            }

                    case .empty:
                        placeholder(width: width)
                    }
                }
                .frame(width: width, height: height)
                .contentShape(cornerShape)
                .accessibilityLabel("Cover for \(title)")
                .onAppear {
                    if normalizedURL == nil {
                        normalizedURL = buildNormalizedURL(from: url, targetWidth: safeWidth(for: Int(width)))
                        dbg("[CoverView] normalizedURL:", normalizedURL?.absoluteString ?? "nil", "original:", url?.absoluteString ?? "nil")
                    }
                    if phase == .empty, let u = sourceURL, currentURLLoading != u {
                        Task { await startLoadingIfNeeded(u) }
                    }
                }
                .onChange(of: url) { _ in
                    retryURL = nil
                    hasRetried = false
                    normalizedURL = nil
                    phase = .empty
                    currentURLLoading = nil
                }
                .onChange(of: sourceURL) { newSource in
                    guard let u = newSource else { return }
                    Task { await startLoadingIfNeeded(u) }
                }
                .transaction { t in t.disablesAnimations = true }
            }
        }
    }

    // MARK: - Manual image loading

    private enum LoadPhase: Equatable {
        case empty
        case loading(URL)
        case success(Image, URL)
        case failure(Error, URL)
        static func == (lhs: LoadPhase, rhs: LoadPhase) -> Bool {
            switch (lhs, rhs) {
            case (.empty, .empty): return true
            case (.loading(let a), .loading(let b)): return a == b
            case (.success(_, let a), .success(_, let b)): return a == b
            case (.failure(_, let a), .failure(_, let b)): return a == b
            default: return false
            }
        }
    }

    private func startLoadingIfNeeded(_ url: URL) async {
        if currentURLLoading == url {
            dbg("[CoverView] skip start, already loading:", url.absoluteString)
            return
        }
        await loadImage(from: url)
    }

    private func loadImage(from url: URL) async {
        await MainActor.run {
            currentURLLoading = url
            phase = .loading(url)
            dbg("[CoverView] start fetch:", url.absoluteString)
        }
        do {
            var req = URLRequest(url: url, timeoutInterval: 45)
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                dbg("[CoverView] HTTP:", http.statusCode, http.url?.absoluteString ?? "-", "type:", http.value(forHTTPHeaderField: "Content-Type") ?? "-")
                guard (200...299).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
            }
            guard let uiImage = UIImage(data: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            let image = Image(uiImage: uiImage)
            await MainActor.run {
                phase = .success(image, url)
                currentURLLoading = nil
            }
        } catch {
            await MainActor.run {
                phase = .failure(error, url)
                currentURLLoading = nil
            }
            await handleFailureRetry(for: url, targetWidth: safeWidth(for: Int(height * aspect)))
        }
    }

    // MARK: - Failure handling and retries

    private func handleFailureRetry(for url: URL, targetWidth: Int) async {
        if shouldRetryCrop(from: url) {
            if let resized = forceResizeReplacingCrop(from: url, targetWidth: targetWidth) {
                dbg("[CoverView] retrying with resize (from crop):", url.absoluteString, "->", resized.absoluteString)
                await MainActor.run {
                    retryURL = resized
                    hasRetried = true
                    phase = .empty
                    currentURLLoading = nil
                }
                return
            } else {
                dbg("[CoverView] could not build resize URL from crop:", url.absoluteString)
                await MainActor.run { hasRetried = true }
                return
            }
        }

        if isRawgHost(url), url.path.contains("/media/resize/"), url.path.contains("/screenshots/") {
            if let original = stripResizePrefix(from: url) {
                dbg("[CoverView] retrying screenshots without resize:", url.absoluteString, "->", original.absoluteString)
                await MainActor.run {
                    retryURL = original
                    phase = .empty
                    currentURLLoading = nil
                }
                return
            }
        }

        if isRawgHost(url), url.path.contains("/media/resize/"), url.path.contains("/games/") {
            if let currentW = extractResizeWidth(from: url) {
                let newW = safeWidth(for: currentW)
                if newW != currentW, let healed = replaceResizeWidth(in: url, to: newW) {
                    dbg("[CoverView] healing resize width:", currentW, "->", newW, "for", url.absoluteString, "->", healed.absoluteString)
                    await MainActor.run {
                        retryURL = healed
                        phase = .empty
                        currentURLLoading = nil
                    }
                    return
                }
            }
        }

        if isRawgHost(url), url.path.contains("/media/resize/"), url.path.contains("/games/") {
            if let originalGames = stripResizePrefix(from: url) {
                dbg("[CoverView] retrying games without resize:", url.absoluteString, "->", originalGames.absoluteString)
                await MainActor.run {
                    retryURL = originalGames
                    phase = .empty
                    currentURLLoading = nil
                }
                return
            }
        }
    }

    private func shouldRetryCrop(from u: URL) -> Bool {
        guard !hasRetried else { return false }
        guard isRawgHost(u) else { return false }
        return u.path.contains("/media/crop/")
    }

    // MARK: - URL helpers

    private func safeWidth(for w: Int) -> Int {
        switch w {
        case ..<256: return 600
        case 256..<513: return 600
        case 513..<1025: return 800
        case 1025..<1600: return 1200
        default: return 1600
        }
    }

    private func buildNormalizedURL(from input: URL?, targetWidth: Int) -> URL? {
        guard let input else { return nil }
        let httpsURL = ensureHTTPS(input)
        guard isRawgHost(httpsURL) else { return httpsURL }

        let path = httpsURL.path

        if path.contains("/screenshots/") {
            return httpsURL
        }

        if path.contains("/media/resize/") || path.contains("/media/crop/") {
            return httpsURL
        }

        if path.contains("/media/") {
            let w = safeWidth(for: targetWidth)
            return RawgImage.resized(from: httpsURL, width: w) ?? httpsURL
        }

        return httpsURL
    }

    private func forceResizeReplacingCrop(from url: URL, targetWidth: Int) -> URL? {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let needle = "/media/crop/"
        var path = comps.path
        guard let range = path.range(of: needle) else { return nil }
        let afterCrop = path[range.upperBound...]
        let components = afterCrop.split(separator: "/", maxSplits: 2, omittingEmptySubsequences: true)
        guard components.count >= 3 else { return nil }
        let remainder = components.dropFirst(2).joined(separator: "/")
        let beforeMedia = path[..<range.lowerBound]
        let w = safeWidth(for: targetWidth)
        var newPath = String(beforeMedia)
        newPath += "/media/resize/\(w)/"
        newPath += remainder.hasPrefix("/") ? String(remainder.dropFirst()) : remainder
        comps.path = newPath
        comps.scheme = "https"
        return comps.url
    }

    private func stripResizePrefix(from url: URL) -> URL? {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var path = comps.path
        let needle = "/media/resize/"
        guard let r = path.range(of: needle) else { return nil }
        let after = path[r.upperBound...]
        let parts = after.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        let rest = parts[1]
        path = "/media/" + rest
        comps.path = path
        comps.scheme = "https"
        return comps.url
    }

    private func replaceResizeWidth(in url: URL, to newWidth: Int) -> URL? {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var path = comps.path
        let needle = "/media/resize/"
        guard let r = path.range(of: needle) else { return nil }
        let after = path[r.upperBound...]
        let parts = after.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        let rest = parts[1]
        path = "/media/resize/\(newWidth)/" + rest
        comps.path = path
        comps.scheme = "https"
        return comps.url
    }

    private func extractResizeWidth(from url: URL) -> Int? {
        let path = url.path
        let needle = "/media/resize/"
        guard let r = path.range(of: needle) else { return nil }
        let after = path[r.upperBound...]
        let parts = after.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        guard let wStr = parts.first, let w = Int(wStr) else { return nil }
        return w
    }

    private func ensureHTTPS(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        if comps.scheme?.lowercased() != "https" {
            comps.scheme = "https"
        }
        return comps.url ?? url
    }

    private func isRawgHost(_ url: URL) -> Bool {
        (url.host?.contains("rawg.io") == true)
    }

    // MARK: - Debug helper

    private func dbg(_ items: Any...) {
        guard debugLogs else { return }
        let line = items.map { String(describing: $0) }.joined(separator: " ")
        print(line)
    }

    // MARK: - Placeholder

    private func placeholder(width: CGFloat) -> some View {
        ZStack {
            cornerShape.fill(Color.ds.surface)
            VStack(spacing: Spacing.s) {
                Image(systemName: "gamecontroller.fill")
                    .font(Typography.h3)
                Text(title)
                    .font(Typography.caption)
                    .foregroundColor(.ds.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)
            }
            .padding(Spacing.s)
        }
        .frame(width: width, height: height)
        .clipShape(cornerShape)
    }
}
