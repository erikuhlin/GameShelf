//
//  DevicePairingView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-27.
//

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct DevicePairingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var profile: ProfileStore

    enum DeviceRole: String, CaseIterable {
        case shareFromThis = "Dela bibliotek"
        case receiveToThis = "Hämta bibliotek"
    }

    @State private var selectedRole: DeviceRole

    // Share State
    @State private var shareCode: String = ""
    @State private var isPreparingShare: Bool = false
    @State private var shareErrorMessage: String?
    @State private var sharePollTask: Task<Void, Never>? = nil

    // Receive State
    @State private var manualInputCode: String = ""
    @State private var isShowingScanner: Bool = false
    @State private var isImporting: Bool = false
    @State private var importStatusText: String = ""
    @State private var importErrorMessage: String?

    // Common Success State
    @State private var isSuccess: Bool = false
    @State private var successTitle: String = "Klart!"
    @State private var successSubtitle: String = ""

    init() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            _selectedRole = State(initialValue: .receiveToThis)
        } else {
            _selectedRole = State(initialValue: .shareFromThis)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    // Tydlig rollväljare
                    Picker("Åtgärd", selection: $selectedRole) {
                        Text("Dela bibliotek").tag(DeviceRole.shareFromThis)
                        Text("Hämta bibliotek").tag(DeviceRole.receiveToThis)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if isSuccess {
                        successView
                    } else if isImporting {
                        importingView
                    } else {
                        switch selectedRole {
                        case .shareFromThis:
                            shareFromThisView
                        case .receiveToThis:
                            receiveToThisView
                        }
                    }

                    Spacer(minLength: 20)
                }
            }
            .background(Color.ds.background.ignoresSafeArea())
            .navigationTitle("Koppla enheter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if selectedRole == .shareFromThis && shareCode.isEmpty {
                    prepareShareSession()
                }
            }
            .onChange(of: selectedRole) { _, newRole in
                if newRole == .shareFromThis && shareCode.isEmpty {
                    prepareShareSession()
                }
            }
            .onDisappear {
                sharePollTask?.cancel()
            }
            .sheet(isPresented: $isShowingScanner) {
                QRCodeScannerView { scannedRaw in
                    isShowingScanner = false
                    handleScannedCode(scannedRaw)
                } onCancel: {
                    isShowingScanner = false
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Vy 1: DELA BIBLIOTEK
    private var shareFromThisView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.ds.brandRed)

                Text("Dela ditt bibliotek")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text("Öppna Gameshelf på din andra enhet eller webben och välj 'Hämta bibliotek' för att ansluta:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 6)

            // QR-kod & Synkkod
            VStack(spacing: 16) {
                let currentUserId = SupabaseAuthManager.shared.persistentUserId
                let qrPayload = "gameshelf://pair?id=\(currentUserId.uuidString)&name=\(profile.username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Spelare")"

                if let qrImage = generateQRCode(from: qrPayload) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190, height: 190)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                }

                if !shareCode.isEmpty {
                    VStack(spacing: 4) {
                        Text("ELLER ANGE KOD MANUELLT:")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        Text(shareCode)
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.ds.brandRed)
                            .tracking(2)
                    }
                } else if isPreparingShare {
                    ProgressView("Skapar synkkod...")
                        .font(.caption)
                }

                if let err = shareErrorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)

            // Alternativ: godkänn kod om den andra enheten visar en kod
            VStack(spacing: 8) {
                Text("Visar din andra enhet en kod istället?")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    TextField("t.ex. GS-4821", text: $manualInputCode)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        approveRemoteDeviceCode()
                    } label: {
                        Text("Godkänn")
                            .bold()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ds.brandRed)
                    .disabled(manualInputCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Vy 2: HÄMTA BIBLIOTEK
    private var receiveToThisView: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.ds.brandRed)

                Text("Hämta ditt bibliotek")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text("Öppna Gameshelf på enheten eller webben där du har dina spel och välj 'Dela bibliotek':")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 6)

            // Huvudknapp: Skanna QR-kod
            VStack(spacing: 16) {
                Button {
                    isShowingScanner = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                        Text("Skanna QR-kod")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ds.brandRed)

                HStack {
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                    Text("ELLER SKRIV IN KOD FRÅN DEN ANDRA ENHETEN")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                }
                .padding(.vertical, 4)

                HStack {
                    TextField("t.ex. GS-4821", text: $manualInputCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if UIPasteboard.general.hasStrings {
                        Button {
                            if let str = UIPasteboard.general.string {
                                manualInputCode = str.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .font(.title3)
                                .padding(10)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                if let err = importErrorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    fetchLibraryUsingCode()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Hämta spel och profil")
                            .bold()
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(Color.ds.brandRed)
                .disabled(manualInputCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Laddningsläge under hämtning
    private var importingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.ds.brandRed)
                .padding(.bottom, 10)

            Text("Synkroniserar...")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(importStatusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
        .padding(.top, 40)
    }

    // MARK: - Success Card
    private var successView: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 68))
                .foregroundStyle(.green)

            Text(successTitle)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(successSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                dismiss()
            } label: {
                Text("Börja utforska")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ds.brandRed)
            .padding(.top, 10)
        }
        .padding(26)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
        .padding(.top, 30)
    }

    // MARK: - Logik: Dela bibliotek från denna enhet
    private func prepareShareSession() {
        sharePollTask?.cancel()
        isPreparingShare = true
        shareErrorMessage = nil

        let currentGames = store.games
        let currentCollections = store.collections

        Task {
            // Ladda upp alla lokala spel till molnet i en snabb batch så servern har allt
            try? await SupabaseSyncService.shared.upsertGames(currentGames)
            for col in currentCollections {
                try? await SupabaseSyncService.shared.upsertCollection(col)
            }

            do {
                let code = try await SupabasePairingService.shared.createPairingSession()
                // Godkänn omedelbart sessionen med denna enhets ID så att vem som helst som knappar in koden direkt får access
                try await SupabasePairingService.shared.approvePairing(code: code, username: profile.username)

                await MainActor.run {
                    self.shareCode = code
                    self.isPreparingShare = false
                }
            } catch {
                await MainActor.run {
                    self.isPreparingShare = false
                    self.shareErrorMessage = "Kunde inte skapa synkkod: \(error.localizedDescription)"
                }
            }
        }
    }

    private func approveRemoteDeviceCode() {
        var clean = manualInputCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !clean.hasPrefix("GS-") { clean = "GS-\(clean)" }

        isPreparingShare = true
        shareErrorMessage = nil

        let currentGames = store.games
        let currentCollections = store.collections

        Task {
            try? await SupabaseSyncService.shared.upsertGames(currentGames)
            for col in currentCollections {
                try? await SupabaseSyncService.shared.upsertCollection(col)
            }

            do {
                try await SupabasePairingService.shared.approvePairing(code: clean, username: profile.username)
                await MainActor.run {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    self.isPreparingShare = false
                    self.successTitle = "Koppling godkänd!"
                    self.successSubtitle = "Ditt bibliotek delas nu med din anslutna enhet."
                    self.isSuccess = true
                }
            } catch {
                await MainActor.run {
                    self.isPreparingShare = false
                    self.shareErrorMessage = "Kunde inte godkänna koden: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Logik: Hämta bibliotek till denna enhet
    private func handleScannedCode(_ rawCode: String) {
        var code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)

        // Kontrollera om det är en direkt QR-länk: gameshelf://pair?id=<UUID>&name=<Name>
        if let url = URL(string: code),
           url.scheme == "gameshelf",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let idStr = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let targetUUID = UUID(uuidString: idStr) {
                let name = components.queryItems?.first(where: { $0.name == "name" })?.value ?? "Spelare"
                importLibrary(forUserId: targetUUID, profileName: name)
                return
            }
        }

        // Om det är en GS-kod i QR
        if code.contains("GS-") {
            if let range = code.range(of: "GS-[A-Z0-9]{4,6}", options: .regularExpression) {
                code = String(code[range])
            }
        }

        self.manualInputCode = code
        fetchLibraryUsingCode()
    }

    private func fetchLibraryUsingCode() {
        var clean = manualInputCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !clean.hasPrefix("GS-") && clean.count >= 4 { clean = "GS-\(clean)" }

        isImporting = true
        importStatusText = "Kontrollerar kod '\(clean)'..."
        importErrorMessage = nil

        Task {
            do {
                guard let session = try await SupabasePairingService.shared.checkPairingSession(code: clean) else {
                    throw NSError(domain: "PairingError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Koden hittades inte eller har inte godkänts än. Se till att du öppnat 'Dela bibliotek' på den andra enheten eller webben."])
                }

                await MainActor.run {
                    importLibrary(forUserId: session.userId, profileName: session.username ?? "Spelare")
                }
            } catch {
                await MainActor.run {
                    self.isImporting = false
                    self.importErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func importLibrary(forUserId targetUserId: UUID, profileName: String) {
        isImporting = true
        importStatusText = "Hämtar profil och spel för '\(profileName)'..."

        Task {
            // 1. Sätt aktiv användare i auth-managern och profile-managern
            await MainActor.run {
                SupabaseAuthManager.shared.setExplicitUserId(targetUserId)
                let manager = ProfileManager.shared
                if let existing = manager.profiles.first(where: { $0.id == targetUserId }) {
                    manager.setActiveProfile(id: existing.id)
                } else {
                    _ = manager.addProfile(name: profileName, id: targetUserId)
                    manager.setActiveProfile(id: targetUserId)
                }
            }

            // 2. Synka profildata
            await profile.importAndSyncProfile(userId: targetUserId)

            // 3. Synka speldata direkt från Supabase och spara lokalt
            do {
                let count = try await store.importAndSyncProfile(userId: targetUserId)

                await MainActor.run {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    self.isImporting = false
                    self.successTitle = "Välkommen, \(profile.username.isEmpty ? profileName : profile.username)!"
                    self.successSubtitle = "\(count) spel och inställningar har laddats ner. Ditt bibliotek och SpelDNA är nu helt synkroniserat mellan dina enheter."
                    self.isSuccess = true
                }
            } catch {
                await MainActor.run {
                    self.isImporting = false
                    self.importErrorMessage = "Kunde inte hämta spel: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Hjälpfunktion: Generera QR-kod bild
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 8, y: 8)
            let scaledImage = outputImage.transformed(by: transform)
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
}
