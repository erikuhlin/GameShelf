//
//  AccountSyncSheet.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-27.
//

import SwiftUI

struct AccountSyncSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var profile: ProfileStore
    @ObservedObject private var authManager = SupabaseAuthManager.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isExistingAccount = false
    @State private var successMessage: String?
    @State private var isSyncingManual = false
    @State private var showingPairingSheet = false

    var body: some View {
        NavigationStack {
            Form {
                // Sektion: Aktuell status
                Section("Konto & Synkstatus") {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .foregroundStyle(Color.ds.brandRed)
                        VStack(alignment: .leading, spacing: 2) {
                            if let user = authManager.currentUser {
                                if user.isLinkedWithRealEmail {
                                    Text("Länkat Gameshelf-konto")
                                        .font(.subheadline.bold())
                                    Text(user.email ?? "Inloggad")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Anonym session (Lokal synk)")
                                        .font(.subheadline.bold())
                                    Text("Lokal ID: \(user.id.uuidString.prefix(8))...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Ej ansluten")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Circle()
                        .fill(authManager.currentUser != nil ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    }

                    HStack {
                        Text("Serveradress")
                        Spacer()
                        Text(SupabaseConfig.baseURLString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingPairingSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                                .foregroundStyle(Color.ds.brandRed)
                            Text("Koppla enheter (Kod/QR)")
                                .bold()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task {
                            isSyncingManual = true
                            await profile.syncWithRemote()
                            await store.syncWithRemote()
                            isSyncingManual = false
                            successMessage = "Biblioteket och profilen har synkroniserats med Supabase!"
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(isSyncingManual ? "Synkroniserar..." : "Tvinga synkronisering nu")
                        }
                    }
                    .disabled(isSyncingManual)
                }

                // Sektion: Länka konto för flerenhets- och webbåtkomst
                if !(authManager.currentUser?.isLinkedWithRealEmail ?? false) {
                    Section {
                        Text("Koppla en e-postadress och ett lösenord till detta bibliotek för att automatiskt komma åt dina spel på alla dina enheter (mobil, surfplatta eller på webben).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Picker("Läge", selection: $isExistingAccount) {
                            Text("Skapa konto").tag(false)
                            Text("Logga in").tag(true)
                        }
                        .pickerStyle(.segmented)

                        TextField("E-postadress", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("Lösenord", text: $password)

                        if let error = authManager.authError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        if let success = successMessage {
                            Text(success)
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        Button {
                            handleAuthAction()
                        } label: {
                            HStack {
                                Spacer()
                                if authManager.isLoading {
                                    ProgressView()
                                } else {
                                    Text(isExistingAccount ? "Logga in och synka" : "Skapa konto och synka")
                                        .bold()
                                }
                                Spacer()
                            }
                        }
                        .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                    } header: {
                        Text(isExistingAccount ? "Logga in med befintligt konto" : "Skapa Gameshelf-konto")
                    }
                } else {
                    Section("Hantering") {
                        Button(role: .destructive) {
                            authManager.clearSession()
                            Task {
                                await authManager.ensureAnonymousAuth()
                            }
                        } label: {
                            Text("Logga ut från Gameshelf-kontot")
                        }
                    }
                }
            }
            .navigationTitle("Konto & Synk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Klar") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPairingSheet) {
                DevicePairingView()
            }
        }
    }

    private func handleAuthAction() {
        successMessage = nil
        Task {
            do {
                if isExistingAccount {
                    try await authManager.signIn(email: email, password: password)
                    await profile.syncWithRemote()
                    await store.syncWithRemote()
                    successMessage = "Inloggad! Spelsamlingen synkroniseras nu mot ditt konto."
                } else {
                    try await authManager.linkAccount(email: email, password: password)
                    await profile.syncWithRemote()
                    await store.syncWithRemote()
                    successMessage = "Ditt konto är nu länkat! Du kan nu logga in på webben eller andra enheter med samma uppgifter."
                }
            } catch {
                // Felmeddelandet sätts automatiskt i authManager.authError
            }
        }
    }
}
