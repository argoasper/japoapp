import Foundation
import SwiftUI

/// On viuen els recursos (data.json): `Bundle.module` quan es compila com a
/// App Playground / paquet Swift (.swiftpm) i `Bundle.main` en un projecte
/// d'Xcode normal (.xcodeproj), on `Bundle.module` no existeix. Així els
/// mateixos fitxers serveixen per als dos projectes sense tocar res.
enum AppResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }
}

struct CityRoute: Codable, Hashable, Identifiable {
    let label: String
    let url: String
    let groupIds: [String]
    let stops: Int
    var id: String { url }
}

struct CityInfo: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let routes: [CityRoute]
}

struct CategoryInfo: Codable, Hashable {
    let label: String
    let icon: String
}

struct Place: Codable, Identifiable, Hashable {
    let id: String
    let seq: Int
    let city: String
    let cityName: String
    let cityIcon: String
    let cityColor: String
    /// Zona o recorregut dins la ciutat (abans era el «dia» de l'itinerari;
    /// ja no s'hi fa cap referència a dies concrets).
    let zone: String
    let order: Int
    let name: String
    let cats: [String]
    let rawCat: String?
    let priority: String?
    let priorityLabel: String?
    let desc: String
    let address: String
    let hours: String
    let duration: String
    let notes: String
    let tags: [String]
    let google: String?
    let apple: String?
    let wiki: String?
    let lat: Double?
    let lng: Double?

    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Place {
    /// True when the place can take part in the "sort by proximity" feature.
    var hasCoords: Bool { lat != nil && lng != nil }

    /// The hand-curated "don't miss this" flag.
    var isMustSee: Bool { priority == "alta" }

    /// Sort weight for the priority filter (lower = more important).
    var priorityRank: Int {
        switch priority {
        case "alta": return 0
        case "mitjana": return 1
        case "baixa": return 2
        default: return 3
        }
    }

    /// Everything the search field should be able to match, as one string.
    /// Built once per place in `DataStore` — never recomputed per keystroke.
    var searchSource: String {
        ([name, desc, address, notes, zone] + tags + cats).joined(separator: " ")
    }
}

/// Diacritic- and case-insensitive normalization used by every search box.
enum SearchText {
    static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ca_ES"))
    }
}

struct AppData: Codable {
    let cities: [CityInfo]
    let cityOrder: [String]
    let catMeta: [String: CategoryInfo]
    let catOrder: [String]
    let places: [Place]
}

/// Les cinc «caixes» que apareixen en entrar a una ciutat (estil app
/// Recordatoris) i les pantalles a què porten.
enum CityScreen: Hashable {
    case places(city: String, mode: PlaceListMode)
    case routes(city: String)
    case transports(city: String)
}

enum PlaceListMode: String, Hashable, CaseIterable {
    case all, pending, visited

    var title: String {
        switch self {
        case .all: return "Tots els llocs"
        case .pending: return "Llocs pendents"
        case .visited: return "Llocs vistos"
        }
    }
    var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .pending: return "circle"
        case .visited: return "checkmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .all: return .gray
        case .pending: return .orange
        case .visited: return .green
        }
    }
}
