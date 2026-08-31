//
//  AvatarPickerSheet.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-31.
//

import SwiftUI
import PhotosUI

struct AvatarPreset: Identifiable {
    let id: String
    let icon: String
    let name: String
    let gradientColors: [Color]
}

struct AvatarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profile: ProfileStore

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isProcessingPhoto = false

    static let presets: [AvatarPreset] = [
        AvatarPreset(id: "preset:gamepad", icon: "🎮", name: "Gamer", gradientColors: [Color(hex: "#3A1414"), Color(hex: "#120B0B")]),
        AvatarPreset(id: "preset:retro_alien", icon: "👾", name: "Retro Pixel", gradientColors: [Color(hex: "#1C1E3A"), Color(hex: "#0F1018")]),
        AvatarPreset(id: "preset:swords", icon: "⚔️", name: "Fantasy RPG", gradientColors: [Color(hex: "#3A2A14"), Color(hex: "#141008")]),
        AvatarPreset(id: "preset:wizard", icon: "🧙", name: "Mage", gradientColors: [Color(hex: "#2A143A"), Color(hex: "#100818")]),
        AvatarPreset(id: "preset:rocket", icon: "🚀", name: "Sci-Fi", gradientColors: [Color(hex: "#14283A"), Color(hex: "#081218")]),
        AvatarPreset(id: "preset:ninja", icon: "🥷", name: "Ninja", gradientColors: [Color(hex: "#222224"), Color(hex: "#0A0A0C")]),
        AvatarPreset(id: "preset:ghost", icon: "👻", name: "Horror", gradientColors: [Color(hex: "#2A1420"), Color(hex: "#140810")]),
        AvatarPreset(id: "preset:coffee", icon: "☕", name: "Cozy Life", gradientColors: [Color(hex: "#3A2218"), Color(hex: "#180E0A")]),
        AvatarPreset(id: "preset:crown", icon: "👑", name: "Trophy Hunter", gradientColors: [Color(hex: "#3A3014"), Color(hex: "#181408")]),
        AvatarPreset(id: "preset:target", icon: "🎯", name: "Tactical", gradientColors: [Color(hex: "#282A14"), Color(hex: "#121408")]),
        AvatarPreset(id: "preset:racer", icon: "🏎️", name: "Racer", gradientColors: [Color(hex: "#3A1414"), Color(hex: "#160808")]),
        AvatarPreset(id: "preset:lightning", icon: "⚡", name: "Challenger", gradientColors: [Color(hex: "#3A142A"), Color(hex: "#180812")])
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Förhandsvisning
                    VStack(spacing: 10) {
                        UserAvatarView(size: 88)
                            .shadow(color: .black.opacity(0.4), radius: 8, y: 3)

                        Text(profile.username.isEmpty ? "Spelare" : profile.username)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, 14)

                    // 1. Initial / Monogram
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Monogram")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        Button {
                            withAnimation {
                                profile.avatarType = "initial"
                            }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#3A1414"), Color(hex: "#0E0D0F")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 44, height: 44)

                                    let letter = profile.username.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "E"
                                    Text(letter)
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Initial (\(profile.username.prefix(1).uppercased()))")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text("Klassiskt monogram med röd gradient")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if profile.avatarType == "initial" {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.red)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(profile.avatarType == "initial" ? Color.red : Color.white.opacity(0.08), lineWidth: 1.2)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // 2. Eget foto
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Eget foto")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(.tertiarySystemFill))
                                        .frame(width: 44, height: 44)

                                    if let data = profile.avatarCustomImageData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 44, height: 44)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "camera.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.avatarCustomImageData != nil ? "Byt eget foto" : "Välj bild från biblioteket")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text("Ladda upp valfri bild från kamerarullen")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if profile.avatarType == "custom" {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.red)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(profile.avatarType == "custom" ? Color.red : Color.white.opacity(0.08), lineWidth: 1.2)
                            )
                        }
                        .buttonStyle(.plain)
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                await processSelectedPhoto(newItem)
                            }
                        }
                    }

                    // 3. Gamer Ikoner (Presets)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gamer-ikoner")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                            ForEach(Self.presets) { preset in
                                let isSelected = profile.avatarType == preset.id
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        profile.avatarType = preset.id
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: preset.gradientColors,
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 58, height: 58)
                                                .overlay(
                                                    Circle()
                                                        .stroke(isSelected ? Color.red : Color.white.opacity(0.12), lineWidth: isSelected ? 2.2 : 1)
                                                )

                                            Text(preset.icon)
                                                .font(.system(size: 24))
                                        }

                                        Text(preset.name)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(isSelected ? Color.red : .secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Välj avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .bold()
                    .foregroundStyle(Color.red)
                }
            }
        }
    }

    private func processSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        isProcessingPhoto = true
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            // Skala ner och komprimera till en rimlig profilbild
            let targetSize = CGSize(width: 250, height: 250)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let resized = renderer.image { _ in
                uiImage.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            if let jpegData = resized.jpegData(compressionQuality: 0.82) {
                await MainActor.run {
                    profile.avatarCustomImageData = jpegData
                    profile.avatarType = "custom"
                    isProcessingPhoto = false
                }
                return
            }
        }
        await MainActor.run {
            isProcessingPhoto = false
        }
    }
}

// MARK: - Återanvändbar UserAvatarView
struct UserAvatarView: View {
    @EnvironmentObject var profile: ProfileStore
    var size: CGFloat = 58

    var body: some View {
        ZStack {
            if profile.avatarType == "custom",
               let data = profile.avatarCustomImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 2))
            } else if profile.avatarType.hasPrefix("preset:"),
                      let preset = AvatarPickerSheet.presets.first(where: { $0.id == profile.avatarType }) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: preset.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 2))

                Text(preset.icon)
                    .font(.system(size: size * 0.44))
            } else {
                // Standard initial
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#3A1414"), Color(hex: "#0E0D0F")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 2))

                let letter = profile.username.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "E"
                Text(letter)
                    .font(.system(size: size * 0.42, weight: .black))
                    .foregroundStyle(.white)
            }
        }
    }
}
