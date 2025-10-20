// No changes made to RawgResultRow.swift as per instructions.
//
//  RawgSearchRow.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-05.
//

import SwiftUI

struct RawgSearchRow: View {
    let item: RawgGame
    let added: Bool
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            coverThumb
                .frame(width: 52, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if added {
                Text("Added")
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.gray.opacity(0.2)))
            } else {
                Button(action: { onAdd() }) {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.ds.brandRed)
            }
        }
    }

    private var coverThumb: some View {
        let url = item.background_image.flatMap { URL(string: $0) }
        return Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallbackThumb
                    @unknown default:
                        fallbackThumb
                    }
                }
            } else {
                fallbackThumb
            }
        }
    }

    private var fallbackThumb: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.thinMaterial)
            .overlay(Image(systemName: "gamecontroller.fill"))
    }

    private var subtitle: String {
        let year = item.released?.prefix(4) ?? ""
        let platforms = (item.platforms ?? []).prefix(2).map { $0.platform.name }.joined(separator: ", ")
        return [platforms, String(year)].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
