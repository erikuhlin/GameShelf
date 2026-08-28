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

            VStack(spacing: 14) {
                // Topprad med badge & formaterat datum
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass.badge.plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse, options: .repeating)

                        Text("KOMMANDE SLÄPP")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.12))
                    .clipShape(Capsule())

                    Spacer()

                    Text(formattedDate(targetDate))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if isToday {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.red)
                        Text("Spelet släpps idag! 🎉")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        Image(systemName: "sparkles")
                            .foregroundStyle(.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                } else {
                    // 4 st tidsblock: Dagar, Timmar, Minuter, Sekunder
                    let days = Int(diff) / 86400
                    let hours = (Int(diff) % 86400) / 3600
                    let minutes = (Int(diff) % 3600) / 60
                    let seconds = Int(diff) % 60

                    HStack(spacing: 6) {
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Future Year Card (Endast År)
    private func futureYearCard(year: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(.red)

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
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Time Unit Box
    private func timeUnitBox(value: Int, unit: String) -> some View {
        VStack(spacing: 3) {
            Text(String(format: "%02d", value))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(unit.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var timeSeparator: some View {
        Text(":")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary.opacity(0.5))
            .padding(.bottom, 12)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
