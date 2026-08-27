//
//  ProfileView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-08.
//

import SwiftUI

/// Enkel profilvy – kopplad till ProfileStore via EnvironmentObject
struct ProfileView: View {
    @EnvironmentObject var profile: ProfileStore
    @EnvironmentObject var store: LibraryStore
    @State private var showingAccountSyncSheet = false
    @State private var showingPairingSheet = false

    private let allPlatforms = [
        "Nintendo (NES/SNES/64/Switch)",
        "PlayStation (PS1–PS5)",
        "Xbox (Classic–Series X|S)",
        "PC",
        "Mobile (iOS/Android)",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Webb & Databassynk") {
                    Button {
                        showingPairingSheet = true
                    } label: {
                        HStack {
                            Label("📱 Parkoppla webbläsare (Kod/QR)", systemImage: "qrcode.viewfinder")
                                .bold()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        showingAccountSyncSheet = true
                    } label: {
                        HStack {
                            Label("Konto- och serverinställningar", systemImage: "gearshape")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Profil & Spelarnamn") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(Color.ds.brandRed)
                        TextField("Ditt spelarnamn", text: $profile.username)
                            .font(.body.weight(.medium))
                    }
                }

                Section("Age") {
                    DatePicker("Birthdate", selection: $profile.birthdate, displayedComponents: .date)
                    Text("Age: \(profile.age)")
                        .foregroundStyle(.secondary)
                }

                Section("Platforms") {
                    ForEach(allPlatforms, id: \.self) { p in
                        Toggle(isOn: Binding(
                            get: { profile.platforms.contains(p) },
                            set: { _ in profile.toggle(p) }
                        )) {
                            Text(p)
                        }
                    }
                }

                Section {
                    Text("Dina val används i Explore för att filtrera rekommendationer och nyheter.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingPairingSheet) {
                DevicePairingView()
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingAccountSyncSheet) {
                AccountSyncSheet()
                    .environmentObject(store)
            }
        }
    }
}
