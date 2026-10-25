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

    @AppStorage("gemini_api_key") private var geminiApiKey: String = ""
    @State private var showingAccountSyncSheet = false
    @State private var showingPairingSheet = false
    @State private var showingAPIKeySheet = false
    @State private var apiKeyDraft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Konto & Enhetssynk") {
                    Button {
                        showingPairingSheet = true
                    } label: {
                        HStack {
                            Label("Koppla enheter (Kod/QR)", systemImage: "arrow.triangle.2.circlepath")
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
                            Label("Konto- och synkinställningar", systemImage: "person.crop.circle.badge.checkmark")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Spelmål") {
                    NavigationLink(destination: GameGoalsView().environmentObject(store).environmentObject(profile)) {
                        HStack {
                            Label("Spelmål \(String(GamingGoalEngine.currentYear))", systemImage: "trophy.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(profile.annualGamingGoal) mål")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("AI & Kapitellistor") {
                    Button {
                        apiKeyDraft = geminiApiKey
                        showingAPIKeySheet = true
                    } label: {
                        HStack {
                            Label("Gemini API-nyckel", systemImage: "sparkles")
                                .foregroundStyle(.primary)
                            Spacer()
                            if geminiApiKey.isEmpty {
                                Text("Ej inlagd")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    Text("Sparad")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingAPIKeySheet) {
                apiKeySheet
            }
        }
    }

    private var apiKeySheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("För att generera 1:1-kapitellistor med AI behövs en gratis Gemini API-nyckel från Google AI Studio. Den sparas lokalt på din enhet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("Klistra in AIzaSy...", text: $apiKeyDraft)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .textContentType(.none)
                            .keyboardType(.asciiCapable)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )

                        Button {
                            if let clip = UIPasteboard.general.string {
                                apiKeyDraft = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.subheadline.bold())
                                Text("Klistra in")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    if !apiKeyDraft.isEmpty {
                        HStack {
                            Button {
                                apiKeyDraft = ""
                            } label: {
                                Text("Rensa text")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            if !geminiApiKey.isEmpty {
                                Button(role: .destructive) {
                                    geminiApiKey = ""
                                    apiKeyDraft = ""
                                    showingAPIKeySheet = false
                                } label: {
                                    Text("Ta bort sparad nyckel")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                        Text("Skaffa en gratis Gemini API-nyckel här (Google AI Studio)")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(20)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Gemini API-nyckel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        showingAPIKeySheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        geminiApiKey = trimmed
                        showingAPIKeySheet = false
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.red)
                    .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                apiKeyDraft = geminiApiKey
            }
        }
        .presentationDetents([.height(310), .medium])
    }
}
