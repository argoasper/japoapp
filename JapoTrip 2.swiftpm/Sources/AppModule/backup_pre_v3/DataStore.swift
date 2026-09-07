import Foundation
import SwiftUI

@MainActor
final class DataStore: ObservableObject {
    @Published var appData: AppData
    @Published var visited: Set<String> {
        didSet { UserDefaults.standard.set(Array(visited), forKey: Self.visitedKey) }
    }

    /// User-defined order of the city tiles on the home screen (drag to
    /// reorder). Falls back to the itinerary's natural order until the user
    /// touches it for the first time.
    @Published var cityOrder: [String] {
        didSet { UserDefaults.standard.set(cityOrder, forKey: Self.cityOrderKey) }
    }

    /// User-defined order of places within a city (drag to reorder), keyed
    /// by city id. Absent for a city until the user reorders it there.
    @Published var placeOrder: [String: [String]] {
        didSet {
            if let data = try? JSONEncoder().encode(placeOrder) {
                UserDefaults.standard.set(data, forKey: Self.placeOrderKey)
            }
        }
    }

    static let visitedKey = "japo_visited_v1"
    static let cityOrderKey = "japo_city_order_v1"
    static let placeOrderKey = "japo_place_order_v1"

    init() {
        guard let url = Bundle.module.url(forResource: "data", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            // Fallback to an empty dataset rather than crashing the app.
            self.appData = AppData(cities: [], cityOrder: [], catMeta: [:], catOrder: [], places: [])
            self.visited = []
            self.cityOrder = []
            self.placeOrder = [:]
            return
        }

        let decoded = Self.decodeResiliently(data)
        self.appData = decoded
        let saved = UserDefaults.standard.array(forKey: Self.visitedKey) as? [String] ?? []
        self.visited = Set(saved)

        if let savedCityOrder = UserDefaults.standard.array(forKey: Self.cityOrderKey) as? [String],
           Set(savedCityOrder) == Set(decoded.cityOrder) {
            self.cityOrder = savedCityOrder
        } else {
            self.cityOrder = decoded.cityOrder
        }

        if let placeOrderData = UserDefaults.standard.data(forKey: Self.placeOrderKey),
           let decodedOrder = try? JSONDecoder().decode([String: [String]].self, from: placeOrderData) {
            self.placeOrder = decodedOrder
        } else {
            self.placeOrder = [:]
        }
    }

    /// A single malformed entry anywhere in `places` (a bad type, a missing
    /// required field after a future manual edit to data.json, etc.) used to
    /// take down the WHOLE dataset: `JSONDecoder` fails the entire `places`
    /// array as soon as one element doesn't decode, and `init()` would then
    /// fall back to an empty app. This decodes each place (and city)
    /// individually via `FailableDecodable` so one bad entry is skipped and
    /// logged instead of blanking out all 235 places.
    private static func decodeResiliently(_ data: Data) -> AppData {
        struct FailableDecodable<Base: Decodable>: Decodable {
            let base: Base?
            init(from decoder: Decoder) throws {
                do {
                    base = try Base(from: decoder)
                } catch {
                    print("⚠️ JapoTrip data.json: skipping malformed entry of type \(Base.self): \(error)")
                    base = nil
                }
            }
        }
        struct RawAppData: Decodable {
            let cities: [FailableDecodable<CityInfo>]
            let cityOrder: [String]
            let catMeta: [String: CategoryInfo]
            let catOrder: [String]
            let places: [FailableDecodable<Place>]
        }

        guard let raw = try? JSONDecoder().decode(RawAppData.self, from: data) else {
            // The file isn't even valid JSON / doesn't match the top-level
            // shape at all — nothing to salvage.
            return AppData(cities: [], cityOrder: [], catMeta: [:], catOrder: [], places: [])
        }
        let places = raw.places.compactMap { $0.base }
        let cities = raw.cities.compactMap { $0.base }
        let skipped = (raw.places.count - places.count) + (raw.cities.count - cities.count)
        if skipped > 0 {
            print("⚠️ JapoTrip data.json: loaded with \(skipped) malformed entr(y/ies) skipped — the rest of the app still works normally.")
        }
        return AppData(cities: cities, cityOrder: raw.cityOrder, catMeta: raw.catMeta, catOrder: raw.catOrder, places: places)
    }

    func toggleVisited(_ id: String) {
        if visited.contains(id) { visited.remove(id) } else { visited.insert(id) }
    }

    func isVisited(_ id: String) -> Bool { visited.contains(id) }

    /// Places for a city in the itinerary's natural (day/seq) order.
    func places(for city: String) -> [Place] {
        appData.places.filter { $0.city == city }.sorted { $0.seq < $1.seq }
    }

    /// Places for a city honoring any manual drag-to-reorder the user has
    /// done for that city; falls back to the natural order otherwise. New
    /// places that aren't part of a saved custom order (shouldn't normally
    /// happen, but defensive) are appended at the end in natural order.
    func orderedPlaces(for city: String) -> [Place] {
        let natural = places(for: city)
        guard let order = placeOrder[city] else { return natural }
        var byId = Dictionary(uniqueKeysWithValues: natural.map { ($0.id, $0) })
        var result: [Place] = []
        result.reserveCapacity(natural.count)
        for id in order {
            if let p = byId.removeValue(forKey: id) { result.append(p) }
        }
        if !byId.isEmpty {
            result.append(contentsOf: natural.filter { byId[$0.id] != nil })
        }
        return result
    }

    /// Applies a drag-to-reorder move within a city's place list.
    func movePlaces(in city: String, from source: IndexSet, to destination: Int) {
        var current = orderedPlaces(for: city).map { $0.id }
        current.move(fromOffsets: source, toOffset: destination)
        placeOrder[city] = current
    }

    /// Applies a drag-to-reorder move of the city tiles on the home screen.
    func moveCity(from source: Int, to destination: Int) {
        guard cityOrder.indices.contains(source) else { return }
        var arr = cityOrder
        let item = arr.remove(at: source)
        let clampedDestination = min(max(destination, 0), arr.count)
        arr.insert(item, at: clampedDestination)
        cityOrder = arr
    }

    func moveCities(from source: IndexSet, to destination: Int) {
        var arr = cityOrder
        arr.move(fromOffsets: source, toOffset: destination)
        cityOrder = arr
    }

    func cityInfo(_ id: String) -> CityInfo? {
        appData.cities.first { $0.id == id }
    }

    func visitedCount(for city: String) -> Int {
        places(for: city).filter { visited.contains($0.id) }.count
    }

    var totalVisited: Int { visited.count }
    var totalPlaces: Int { appData.places.count }
}
