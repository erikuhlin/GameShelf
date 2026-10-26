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
        if let targetDate = releaseDate {
            let startOfToday = Calendar.current.startOfDay(for: Date())
            if targetDate >= startOfToday {
                if targetDate > Date() && targetDate.isYearPlaceholderDate {
                    let year = releaseYear ?? Calendar.current.component(.year, from: targetDate)
                    futureYearCard(year: year > 0 ? year : nil)
                } else {
                    compactCountdownRow(targetDate: targetDate)
                }
            }
        } else if let year = releaseYear, year > Calendar.current.component(.year, from: Date()) {
            futureYearCard(year: year)
        }
    }

    // MARK: - Kompakt enrads-nedräkning ("Om 25 dagar · 19 nov")
    private func compactCountdownRow(targetDate: Date) -> some View {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let startOfTarget = cal.startOfDay(for: targetDate)
        let days = max(0, cal.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0)
        let isToday = days == 0

        return HStack(spacing: 10) {
            Image(systemName: isToday ? "sparkles" : "calendar.badge.clock")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.red)

            if isToday {
                Text("Spelet släpps idag! 🎉")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            } else {
                HStack(spacing: 0) {
                    Text(days == 1 ? "Om 1 dag" : "Om \(days) dagar")
                        .foregroundStyle(.primary)
                        .fontWeight(.bold)
                    Text(" · ")
                        .foregroundStyle(.secondary)
                        .fontWeight(.bold)
                    Text(shortDateText(targetDate))
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)
            }

            Spacer(minLength: 4)

            Text("KOMMANDE")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.12), in: Capsule())
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.25), lineWidth: 0.8)
        )
    }

    // MARK: - Future Year Card (Endast År eller Kommande)
    private func futureYearCard(year: Int?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.red)

            if let y = year, y > 0 {
                Text("Planerat släpp · \(String(y))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } else {
                Text("Kommande lansering · Datum ej fastställt")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 4)

            Text("KOMMANDE")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.12), in: Capsule())
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.25), lineWidth: 0.8)
        )
    }

    private func shortDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        let sameYear = Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: Date())
        formatter.dateFormat = sameYear ? "d MMM" : "d MMM yyyy"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }
}
