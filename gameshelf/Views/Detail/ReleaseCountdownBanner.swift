//
//  ReleaseCountdownBanner.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-28.
//

import SwiftUI

struct ReleaseCountdownBanner: View {
    let releaseDate: Date?
    let releaseYear: Int?

    var body: some View {
        if let targetDate = releaseDate, targetDate > Date() {
            liveCountdownCard(targetDate: targetDate)
        } else if let year = releaseYear, year > Calendar.current.component(.year, from: Date()) {
            futureYearCard(year: year)
        }
    }

    // MARK: - Live Countdown Card (Exakt datum)
    private func liveCountdownCard(targetDate: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let now = timeline.date
            let diff = max(0, targetDate.timeIntervalSince(now))
            let isToday = Calendar.current.isDate(targetDate, inSameDayAs: now) || diff <= 0

            VStack(spacing: 12) {
                // Topprad med badge & formaterat datum
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass.badge.plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.orange)
                            .symbolEffect(.pulse, options: .repeating)

                        Text("KOMMANDE SLÄPP")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(1.0)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())

                    Spacer()

                    Text(formattedDate(targetDate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if isToday {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                        Text("Spelet släpps idag! 🎉")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    // 4 st tidsblock: Dagar, Timmar, Minuter, Sekunder
                    let days = Int(diff) / 86400
                    let hours = (Int(diff) % 86400) / 3600
                    let minutes = (Int(diff) % 3600) / 60
                    let seconds = Int(diff) % 60

                    HStack(spacing: 8) {
                        timeUnitBox(value: days, unit: "Dagar")
                        timeSeparator
                        timeUnitBox(value: hours, unit: "Timmar")
                        timeSeparator
                        timeUnitBox(value: minutes, unit: "Minuter")
                        timeSeparator
                        timeUnitBox(value: seconds, unit: "Sekunder")
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.11, blue: 0.08),
                                Color(red: 0.10, green: 0.09, blue: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.6), Color.red.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.orange.opacity(0.12), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Future Year Card (Endast År)
    private func futureYearCard(year: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Kommande lansering")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Planerat släpp: \(String(year))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text("\(year)")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.12, green: 0.10, blue: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Time Unit Box
    private func timeUnitBox(value: Int, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(white: 0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text(unit.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var timeSeparator: some View {
        Text(":")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.orange.opacity(0.7))
            .padding(.bottom, 12)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
