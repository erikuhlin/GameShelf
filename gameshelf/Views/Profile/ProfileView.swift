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
        }
    }
}
