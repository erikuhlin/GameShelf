//
//  CoverView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI

struct CoverView: View {
    let title: String
    let url: URL?
    var corner: CGFloat = Radius.m
    var height: CGFloat = 160

    var body: some View {
        ZStack {
            // Background holder with fixed size and corner
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.ds.surface)

            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                            .compositingGroup()
                            .transition(.identity)
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.ds.brandRed)
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(height: height)
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .accessibilityLabel("Cover for \(title)")
    }

    private var placeholder: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "gamecontroller.fill")
                .font(Typography.h3)
            Text(title)
                .font(Typography.caption)
                .foregroundColor(.ds.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .padding(Spacing.s)
    }
}
