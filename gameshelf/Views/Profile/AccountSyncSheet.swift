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
                                    Text("Länkat webbkonto")
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
                            Text("Parkoppla med webbläsare (Kod/QR)")
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
                            await store.syncWithRemote()
                            isSyncingManual = false
                            successMessage = "Biblioteket har synkroniserats med Supabase!"
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(isSyncingManual ? "Synkroniserar..." : "Tvinga synkronisering nu")
                        }
                    }
                    .disabled(isSyncingManual)
                }

                // Sektion: Länka konto för webbåtkomst
                if !(authManager.currentUser?.isLinkedWithRealEmail ?? false) {
                    Section {
                        Text("Koppla din egen e-postadress och ett lösenord till detta konto, så kan du logga in på webben (http://localhost:3000/login) och se samma spel där.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Picker("Läge", selection: $isExistingAccount) {
                            Text("Skapa inloggning").tag(false)
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
                                    Text(isExistingAccount ? "Logga in på webbkonto" : "Länka till webbkonto")
                                        .bold()
                                }
                                Spacer()
                            }
                        }
                        .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                    } header: {
                        Text(isExistingAccount ? "Logga in med befintligt konto" : "Anslut till webben (Skapa inloggning)")
                    }
                } else {
                    Section("Hantering") {
                        Button(role: .destructive) {
                            authManager.clearSession()
                            Task {
                                await authManager.ensureAnonymousAuth()
                            }
                        } label: {
                            Text("Logga ut från webbkonto")
                        }
                    }
                }
            }
            .navigationTitle("Webb & Synk")
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
                    await store.syncWithRemote()
                    successMessage = "Inloggad! Spelsamlingen synkas nu mot ditt webbkonto."
                } else {
                    try await authManager.linkAccount(email: email, password: password)
                    await store.syncWithRemote()
                    successMessage = "Ditt konto är nu länkat! Du kan nu logga in på webben med samma uppgifter."
                }
            } catch {
                // Felmeddelandet sätts automatiskt i authManager.authError
            }
        }
    }
}
