//
//  DevicePairingView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-27.
//

import SwiftUI
import UIKit

struct DevicePairingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var profile: ProfileStore

    @State private var pairingCode: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var isSuccess: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header Graphic
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.ds.brandRed.opacity(0.12))
                                .frame(width: 88, height: 88)

                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(Color.ds.brandRed)
                        }

                        Text("Parkoppla med webbläsare")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        Text("Öppna http://localhost:3000 i webbläsaren och klicka på 'Anslut iPhone' för att visa din parkopplingskod eller QR-kod.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)

                    if isSuccess {
                        // Success View
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.green)

                            Text("Webbläsaren är ansluten!")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text("Ditt spelbibliotek synkas nu direkt i realtid med din webbläsare.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button {
                                dismiss()
                            } label: {
                                Text("Klar")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.ds.brandRed)
                            .padding(.top, 8)
                        }
                        .padding(24)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 20)
                    } else {
                        // Code Input Card
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Ange kod från webben")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            HStack {
                                TextField("t.ex. GS-4821", text: $pairingCode)
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 12)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                if UIPasteboard.general.hasStrings {
                                    Button {
                                        if let str = UIPasteboard.general.string {
                                            pairingCode = str.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                        }
                                    } label: {
                                        Image(systemName: "doc.on.clipboard")
                                            .font(.title3)
                                            .padding(12)
                                            .background(Color(.tertiarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }

                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            Button {
                                handleApprove()
                            } label: {
                                HStack {
                                    Spacer()
                                    if isProcessing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.right.circle.fill")
                                        Text("Godkänn och anslut webben")
                                            .bold()
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.ds.brandRed)
                            .disabled(pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                        }
                        .padding(20)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 20)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Parkoppling")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func handleApprove() {
        var codeToSubmit = pairingCode
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if !codeToSubmit.hasPrefix("GS-") && !codeToSubmit.isEmpty {
            codeToSubmit = "GS-\(codeToSubmit)"
        }

        isProcessing = true
        errorMessage = nil

        let gamesToUpload = store.games
        let collectionsToUpload = store.collections

        Task {
            do {
                // Synka alla lokala spel till databasen
                for game in gamesToUpload {
                    try await SupabaseSyncService.shared.upsertGame(game)
                }

                for col in collectionsToUpload {
                    try await SupabaseSyncService.shared.upsertCollection(col)
                }

                // Godkänn parkopplingssessionen
                try await SupabasePairingService.shared.approvePairing(code: codeToSubmit, username: profile.username)

                await MainActor.run {
                    self.isProcessing = false
                    self.isSuccess = true
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
