//
//  CoverView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI

// MARK: - In-Memory Image Cache för blixtsnabb rendering
final class CoverImageCache: @unchecked Sendable {
    static let shared = CoverImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 250 // max 250 bilder i minnet
        cache.totalCostLimit = 60 * 1024 * 1024 // ~60 MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

struct CoverView: View {
    let title: String
    let url: URL?
    var corner: CGFloat = Radius.m
    var height: CGFloat = 160

    enum FitMode { case fill, fit }
    var fitMode: FitMode = .fill
    var fullWidth: Bool = false

    private var aspect: CGFloat { 3.0 / 4.0 }
    private var cornerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
    }

    @State private var loadedImage: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var hasFailed: Bool = false

    var body: some View {
        Group {
            if fullWidth {
                GeometryReader { geo in
                    contentView(width: geo.size.width)
                }
                .frame(height: height)
            } else {
                contentView(width: height * aspect)
            }
        }
    }

    @ViewBuilder
    private func contentView(width: CGFloat) -> some View {
        ZStack {
            cornerShape.fill(Color.ds.surface)

            if let img = loadedImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: fitMode == .fill ? .fill : .fit)
                    .frame(width: width, height: height)
                    .clipped()
                    .clipShape(cornerShape)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.ds.brandRed)
                    .frame(width: width, height: height)
            } else {
                placeholder(width: width)
            }
        }
        .frame(width: width, height: height)
        .contentShape(cornerShape)
        .accessibilityLabel("Cover for \(title)")
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = url else {
            loadedImage = nil
            isLoading = false
            hasFailed = false
            return
        }

        // 1. Kolla minnescachen först
        if let cached = CoverImageCache.shared.image(for: url) {
            self.loadedImage = cached
            self.isLoading = false
            self.hasFailed = false
            return
        }

        // 2. Ladda asynkront från nätverket
        isLoading = true
        hasFailed = false

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 20

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
                  let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    self.isLoading = false
                    self.hasFailed = true
                }
                return
            }

            CoverImageCache.shared.insert(uiImage, for: url)

            await MainActor.run {
                self.loadedImage = uiImage
                self.isLoading = false
                self.hasFailed = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.hasFailed = true
            }
        }
    }

    // MARK: - Placeholder
    private func placeholder(width: CGFloat) -> some View {
        ZStack {
            cornerShape.fill(Color.ds.surface)
            VStack(spacing: Spacing.s) {
                Image(systemName: "gamecontroller.fill")
                    .font(Typography.h3)
                    .foregroundStyle(.secondary.opacity(0.6))
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
