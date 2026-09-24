import Foundation

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
    let day: String
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

struct AppData: Codable {
    let cities: [CityInfo]
    let cityOrder: [String]
    let catMeta: [String: CategoryInfo]
    let catOrder: [String]
    let places: [Place]
}
