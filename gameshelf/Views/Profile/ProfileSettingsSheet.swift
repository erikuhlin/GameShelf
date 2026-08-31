//
//  ProfileSettingsSheet.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-31.
//

import SwiftUI

struct ProfileSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var profile: ProfileStore

    @State private var showingAccountSyncSheet = false
    @State private var showingPairingSheet = false

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

                Section("Spelmål") {
                    Stepper("Årligt spelmål: \(profile.annualGamingGoal) spel", value: $profile.annualGamingGoal, in: 1...100)
                }

                Section("Om Gameshelf") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0 (Release Candidate)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .font(.body.bold())
                    .foregroundStyle(Color.red)
                }
            }
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
