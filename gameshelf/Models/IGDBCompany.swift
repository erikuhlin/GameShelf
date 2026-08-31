//
//  IGDBCompany.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-31.
//

import Foundation

enum CompanyRole: String, Identifiable, Sendable {
    case developer = "Utvecklare"
    case publisher = "Utgivare"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .developer: return "hammer.fill"
        case .publisher: return "building.2.fill"
        }
    }
}

struct IGDBCompany: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let description: String?
    let startDate: Int?
    let country: Int?
    let url: String?
    let logo: IGDBImage?

    enum CodingKeys: String, CodingKey {
        case id, name, description, country, url, logo
        case startDate = "start_date"
    }

    var logoURL: URL? {
        logo?.url(size: "t_logo_med")
    }

    var foundedYear: Int? {
        guard let startDate = startDate else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(startDate))
        return Calendar.current.component(.year, from: date)
    }
}
