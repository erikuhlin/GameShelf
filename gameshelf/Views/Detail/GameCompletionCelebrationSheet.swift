//
//  GameCompletionCelebrationSheet.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-09-10.
//

import SwiftUI

struct GameCompletionCelebrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let game: Game
    let onSave: (Game) -> Void

    @State private var completedDate: Date
    @State private var rating: Int
    @State private var selectedPlatform: String
    @State private var reviewNotes: String
    @State private var hoursPlayedText: String
    @State private var showConfetti = false

    init(game: Game, onSave: @escaping (Game) -> Void) {
        self.game = game
        self.onSave = onSave

        _completedDate = State(initialValue: game.completedDate ?? Date())
        _rating = State(initialValue: game.rating ?? 0)
        _selectedPlatform = State(initialValue: game.platforms.first ?? "PlayStation 5")
        _reviewNotes = State(initialValue: game.notes)
        if let h = game.hoursPlayed, h > 0 {
            _hoursPlayedText = State(initialValue: String(format: h.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", h))
        } else if let est = game.estimatedHours, est > 0 {
            _hoursPlayedText = State(initialValue: "\(est)")
        } else {
            _hoursPlayedText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Celebration Header
                    headerSection

                    // Form Fields Card
                    VStack(spacing: 20) {
                        // Rating Selector (1–10)
                        ratingSection

                        Divider()
                            .background(Color.white.opacity(0.1))

                        // Completion Date Picker
                        HStack {
                            Label("Klardatum", systemImage: "calendar")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)

                            Spacer()

                            DatePicker(
                                "",
                                selection: $completedDate,
                                in: ...Date(),
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                            .tint(.purple)
                        }

                        // Platform Selector
                        if !game.platforms.isEmpty {
                            Divider()
                                .background(Color.white.opacity(0.1))

                            HStack {
                                Label("Plattform", systemImage: "gamecontroller.fill")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)

                                Spacer()

                                if game.platforms.count == 1 {
                                    Text(game.platforms[0])
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Picker("Plattform", selection: $selectedPlatform) {
                                        ForEach(game.platforms, id: \.self) { plat in
                                            Text(plat).tag(plat)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.purple)
                                }
                            }
                        }

                        // Hours played
                        Divider()
                            .background(Color.white.opacity(0.1))

                        HStack {
                            Label("Speltid (timmar)", systemImage: "clock.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)

                            Spacer()

                            TextField("Valfritt", text: $hoursPlayedText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                        }

                        Divider()
                            .background(Color.white.opacity(0.1))

                        // Mini-recension & Slutord
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Slutord & Mini-recension", systemImage: "quote.opening")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text("Valfritt")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            ZStack(alignment: .topLeading) {
                                if reviewNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Vad tyckte du om spelet? Dina starkaste minnen, betygsmotivering, styrkor och svagheter...")
                                        .font(.subheadline)
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                }

                                TextEditor(text: $reviewNotes)
                                    .font(.subheadline)
                                    .frame(minHeight: 110)
                                    .padding(8)
                                    .scrollContentBackground(.hidden)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                    )

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            saveAndDismiss()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Spara i Speldagboken")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.indigo],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.purple.opacity(0.4), radius: 8, y: 3)
                        }

                        Button {
                            skipDetailsAndDismiss()
                        } label: {
                            Text("Hoppa över detaljer")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Genomspelat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showConfetti = true
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                // Game Cover
                if let url = game.coverURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 90, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.35), radius: 10, y: 5)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.25))
                        .frame(width: 90, height: 120)
                        .overlay(
                            Image(systemName: "gamecontroller.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.purple)
                        )
                }

                // Trophy Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.orange.opacity(0.5), radius: 6, y: 2)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: 8, y: 8)
                .scaleEffect(showConfetti ? 1.0 : 0.4)
            }

            VStack(spacing: 4) {
                Text("Grattis!")
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(.purple)

                Text(game.title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("Du har klarat spelet!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Rating Selector
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Ditt betyg", systemImage: "star.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Spacer()

                if rating > 0 {
                    HStack(spacing: 4) {
                        Text("\(rating)")
                            .font(.headline.bold())
                            .foregroundStyle(.yellow)
                        Text("/ 10")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Ej betygsatt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Interactive 1-10 Pill / Star Picker
            HStack(spacing: 5) {
                ForEach(1...10, id: \.self) { num in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        rating = (rating == num) ? 0 : num
                    } label: {
                        Text("\(num)")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(
                                rating >= num
                                    ? (rating == num ? Color.yellow : Color.yellow.opacity(0.25))
                                    : Color(.tertiarySystemFill)
                            )
                            .foregroundStyle(
                                rating >= num
                                    ? (rating == num ? Color.black : Color.yellow)
                                    : Color.secondary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Save Actions
    private func saveAndDismiss() {
        var updated = game
        updated.status = .completed
        updated.storyProgress = .completed
        updated.isBacklog = false
        updated.completedDate = completedDate
        let cal = Calendar.current
        updated.completedYear = cal.component(.year, from: completedDate)
        if rating > 0 {
            updated.rating = rating
        }
        if !reviewNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.notes = reviewNotes
            updated.noteUpdatedAt = Date()
        }
        if let h = Double(hoursPlayedText.replacingOccurrences(of: ",", with: ".")) {
            updated.hoursPlayed = h
        }
        if !selectedPlatform.isEmpty && !updated.platforms.contains(selectedPlatform) {
            updated.platforms.insert(selectedPlatform, at: 0)
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSave(updated)
        dismiss()
    }

    private func skipDetailsAndDismiss() {
        var updated = game
        updated.status = .completed
        updated.storyProgress = .completed
        updated.isBacklog = false
        updated.completedDate = Date()
        let cal = Calendar.current
        updated.completedYear = cal.component(.year, from: Date())

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSave(updated)
        dismiss()
    }
}
