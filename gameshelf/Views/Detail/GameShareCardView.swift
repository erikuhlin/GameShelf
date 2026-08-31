//
//  GameShareCardView.swift
//  gameshelf
//
//  Created by Antigravity on 2026-08-30.
//

import SwiftUI

struct GameShareCardView: View {
    let gameTitle: String
    let developer: String?
    let releaseYear: Int?
    var releaseDateText: String? = nil
    let coverURL: URL?
    var preloadedCover: UIImage? = nil
    let userRating: Int?
    let criticRating: Int?
    let status: PlayStatus?
    let platform: String?
    let hoursPlayed: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Topp: GameShelf Branding
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.red)
                    Text("GameShelf")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                if let platform = platform, !platform.isEmpty {
                    Text(platform)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer(minLength: 12)

            // Omslagsbild med 3D-skugga (stödjer preloadedCover för ImageRenderer)
            Group {
                if let img = preloadedCover {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    CoverView(title: gameTitle, url: coverURL, corner: 14, height: 210)
                        .frame(width: 150, height: 210)
                }
            }
            .shadow(color: .red.opacity(0.2), radius: 18, x: 0, y: 8)
            .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )

            Spacer(minLength: 14)

            // Titel & Info
            VStack(spacing: 4) {
                Text(gameTitle)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)

                HStack(spacing: 6) {
                    if let dev = developer, !dev.isEmpty {
                        Text(dev)
                    }
                    if developer != nil && (releaseDateText != nil || releaseYear != nil) {
                        Text("•")
                    }
                    if let dateText = releaseDateText, !dateText.isEmpty {
                        Text(dateText)
                    } else if let year = releaseYear, year > 0 {
                        Text(String(year))
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 16)

            // Betyg & Statuskort
            HStack(spacing: 12) {
                if let rating = userRating, rating > 0 {
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.yellow)
                            Text("\(rating)/10")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text("Mitt betyg")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let st = status {
                    VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: st.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(st.color)
                            Text(st.rawValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text("Status")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let hours = hoursPlayed, hours > 0 {
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue)
                            Text("\(hours)h")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text("Speltid")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 20)

            // Botten: Avslutande diskret banner
            Text("Sparat med GameShelf för iOS")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 20)
        }
        .frame(width: 330, height: 500)
        .background(
            ZStack {
                Color(red: 14/255, green: 20/255, blue: 34/255)
                
                // Mjuk bakgrundsglöd
                Circle()
                    .fill(Color.red.opacity(0.25))
                    .blur(radius: 50)
                    .offset(x: -80, y: -100)

                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .blur(radius: 60)
                    .offset(x: 80, y: 120)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct GameShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let cardView: GameShareCardView
    @State private var preloadedCover: UIImage? = nil
    @State private var renderedImage: UIImage? = nil
    @State private var showingActivitySheet: Bool = false
    @State private var isRendering: Bool = false

    private var activeCardView: GameShareCardView {
        var copy = cardView
        copy.preloadedCover = preloadedCover
        return copy
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                activeCardView
                    .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 10)

                Spacer()

                Button {
                    Task {
                        await renderAndShare()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRendering {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isRendering ? "Förbereder bild..." : "Dela eller spara bild")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isRendering)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(Color.black.opacity(0.85).ignoresSafeArea())
            .navigationTitle("Dela spelkort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                }
            }
            .task {
                await loadCoverImage()
            }
            .sheet(isPresented: $showingActivitySheet) {
                if let image = renderedImage {
                    ShareActivityView(activityItems: [image])
                }
            }
        }
    }

    private func loadCoverImage() async {
        guard let url = cardView.coverURL else { return }
        // 1. Snabbkoll i in-memory cache
        if let cached = CoverImageCache.shared.image(for: url) {
            await MainActor.run {
                self.preloadedCover = cached
            }
            return
        }

        // 2. Ladda ner asynkront om ej i cache
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) {
                CoverImageCache.shared.insert(img, for: url)
                await MainActor.run {
                    self.preloadedCover = img
                }
            }
        } catch {
            print("[GameShareSheet] Kunde inte ladda omslagsbild för delning: \(error)")
        }
    }

    @MainActor
    private func renderAndShare() async {
        isRendering = true
        defer { isRendering = false }

        // Säkerställ att bilden är laddad innan rendering
        if preloadedCover == nil && cardView.coverURL != nil {
            await loadCoverImage()
        }

        let renderer = ImageRenderer(content: activeCardView)
        renderer.scale = displayScale
        if let uiImage = renderer.uiImage {
            self.renderedImage = uiImage
            self.showingActivitySheet = true
        }
    }
}
