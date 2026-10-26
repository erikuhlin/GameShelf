//
//  CoverView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI
import CryptoKit

// MARK: - Tvåstegs Image Cache (Minne + Persistent Disk) för blixtsnabb & offline rendering
final class CoverImageCache: @unchecked Sendable {
    static let shared = CoverImageCache()
    private let memoryCache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheDirectory: URL
    private let ioQueue = DispatchQueue(label: "gameshelf.covercache.disk", qos: .utility)

    private init() {
        memoryCache.countLimit = 350 // max 350 bilder i minnet
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // ~100 MB RAM

        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheFolder = paths[0].appendingPathComponent("GameCovers", isDirectory: true)
        if !FileManager.default.fileExists(atPath: cacheFolder.path) {
            try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        }
        self.diskCacheDirectory = cacheFolder
    }

    private func diskFileURL(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return diskCacheDirectory.appendingPathComponent(hashString).appendingPathExtension("img")
    }

    func image(for url: URL) -> UIImage? {
        // 1. Blixtsnabb minnescache (0 ms)
        if let memoryImage = memoryCache.object(forKey: url as NSURL) {
            return memoryImage
        }

        // 2. Persistent diskcache (fungerar offline och vid omstart)
        let fileURL = diskFileURL(for: url)
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let diskImage = UIImage(data: data) {
            memoryCache.setObject(diskImage, forKey: url as NSURL)
            return diskImage
        }

        return nil
    }

    func insert(_ image: UIImage, data: Data? = nil, for url: URL) {
        memoryCache.setObject(image, forKey: url as NSURL)

        let fileURL = diskFileURL(for: url)
        ioQueue.async {
            if let rawData = data {
                try? rawData.write(to: fileURL, options: .atomic)
            } else if let jpegData = image.jpegData(compressionQuality: 0.88) {
                try? jpegData.write(to: fileURL, options: .atomic)
            }
        }
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

    init(
        title: String,
        url: URL?,
        corner: CGFloat = Radius.m,
        height: CGFloat = 160,
        fitMode: FitMode = .fill,
        fullWidth: Bool = false
    ) {
        self.title = title
        self.url = url
        self.corner = corner
        self.height = height
        self.fitMode = fitMode
        self.fullWidth = fullWidth
        if let u = url, let cached = CoverImageCache.shared.image(for: u) {
            self._loadedImage = State(initialValue: cached)
        }
    }

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

            CoverImageCache.shared.insert(uiImage, data: data, for: url)

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
            LinearGradient(
                colors: [Color.ds.surface, Color(.tertiarySystemFill)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
            }
            .padding(8)
        }
        .frame(width: width, height: height)
        .overlay(cornerShape.stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(cornerShape)
    }
}
