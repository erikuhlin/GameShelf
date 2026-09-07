//
//  ProfileSwitcherView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-09-06.
//

import SwiftUI

struct ProfileSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var store: LibraryStore
    @ObservedObject private var profileManager = ProfileManager.shared

    @State private var showingAddProfileSheet = false
    @State private var showingPairingSheet = false
    @State private var newProfileName = ""
    @State private var selectedPreset = "preset:gamepad"
    @State private var profileToDelete: UserProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.ds.brandRed)

                        Text("Vem spelar?")
                            .font(.title.bold())
                            .foregroundStyle(.primary)

                        Text("Växla mellan sparade profiler på denna enhet eller lägg till en ny profil.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 10)

                    // Profil-kort i rutnät
                    let columns = [
                        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
                    ]

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(profileManager.profiles) { item in
                            let isActive = item.id == profileManager.activeProfileId

                            Button {
                                selectProfile(item)
                            } label: {
                                VStack(spacing: 12) {
                                    ZStack(alignment: .topTrailing) {
                                        profileAvatar(for: item, size: 76)

                                        if isActive {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.white, Color.ds.brandRed)
                                                .background(Circle().fill(Color.black))
                                                .offset(x: 4, y: -4)
                                        }
                                    }

                                    VStack(spacing: 4) {
                                        Text(item.name.isEmpty ? "Spelare" : item.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        if isActive {
                                            Text("Aktiv nu")
                                                .font(.caption2.bold())
                                                .foregroundStyle(Color.ds.brandRed)
                                        } else if item.linkedEmail != nil {
                                            Text("Synkad")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(isActive ? Color.ds.brandRed.opacity(0.12) : Color(.secondarySystemGroupedBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(isActive ? Color.ds.brandRed : Color.primary.opacity(0.08), lineWidth: isActive ? 2 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if profileManager.profiles.count > 1 {
                                    Button(role: .destructive) {
                                        profileToDelete = item
                                    } label: {
                                        Label("Ta bort från denna enhet", systemImage: "trash")
                                    }
                                }
                            }
                        }

                        // Knapp för att lägga till profil
                        Button {
                            showingAddProfileSheet = true
                        } label: {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6]))
                                        .frame(width: 76, height: 76)

                                    Image(systemName: "plus")
                                        .font(.title2.bold())
                                        .foregroundStyle(.secondary)
                                }

                                VStack(spacing: 4) {
                                    Text("Lägg till")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Ny profil")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 10)
                            .background(Color(.secondarySystemGroupedBackground).opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    // Snabbknapp: Synka med annan enhet eller webb
                    VStack(spacing: 12) {
                        Button {
                            showingPairingSheet = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.headline)
                                Text("Koppla profil från annan enhet / webb")
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                }
                .padding(.vertical, 16)
            }
            .background(Color.ds.background.ignoresSafeArea())
            .navigationTitle("Profiler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Klar") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Ta bort profil", isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Ta bort \(profileToDelete?.name ?? "profilen") från enheten", role: .destructive) {
                    if let target = profileToDelete {
                        profileManager.deleteProfile(id: target.id)
                        if profileManager.activeProfileId != target.id {
                            profile.loadProfile(for: profileManager.activeProfileId)
                            store.switchToProfile(id: profileManager.activeProfileId)
                        }
                    }
                }
                Button("Avbryt", role: .cancel) {
                    profileToDelete = nil
                }
            } message: {
                Text("Detta tar endast bort profilen från denna enhet. Spel som är synkade till molnet påverkas inte.")
            }
            .sheet(isPresented: $showingAddProfileSheet) {
                createProfileSheet
            }
            .sheet(isPresented: $showingPairingSheet) {
                DevicePairingView()
            }
        }
    }

    private func selectProfile(_ item: UserProfile) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        profileManager.setActiveProfile(id: item.id)
        profile.switchToProfile(id: item.id)
        store.switchToProfile(id: item.id)
        dismiss()
    }

    @ViewBuilder
    private func profileAvatar(for item: UserProfile, size: CGFloat) -> some View {
        if item.avatarType == "custom",
           let data = item.avatarCustomImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if item.avatarType.hasPrefix("preset:"),
                  let preset = AvatarPickerSheet.presets.first(where: { $0.id == item.avatarType }) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: preset.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Text(preset.icon)
                        .font(.system(size: size * 0.44))
                )
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#3A1414"), Color(hex: "#0E0D0F")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Text(item.name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }

    private var createProfileSheet: some View {
        NavigationStack {
            Form {
                Section("Profilnamn") {
                    TextField("Ange namn eller gamer-tag...", text: $newProfileName)
                }

                Section("Välj avatar") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(AvatarPickerSheet.presets) { preset in
                                let isSelected = selectedPreset == preset.id
                                Button {
                                    selectedPreset = preset.id
                                } label: {
                                    Text(preset.icon)
                                        .font(.title2)
                                        .padding(10)
                                        .background(isSelected ? Color.ds.brandRed.opacity(0.3) : Color(.tertiarySystemFill))
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle().stroke(isSelected ? Color.ds.brandRed : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        let trimmed = newProfileName.trimmingCharacters(in: .whitespaces)
                        let newProfile = profileManager.addProfile(
                            name: trimmed.isEmpty ? "Ny spelare" : trimmed,
                            avatarType: selectedPreset
                        )
                        showingAddProfileSheet = false
                        selectProfile(newProfile)
                    } label: {
                        Text("Skapa och börja spela")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Ny profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        showingAddProfileSheet = false
                    }
                }
            }
        }
    }
}
