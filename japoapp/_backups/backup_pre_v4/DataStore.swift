import Foundation
import SwiftUI

@MainActor
final class DataStore: ObservableObject {
    @Published var appData: AppData
    @Published var visited: Set<String> {
        didSet { scheduleVisitedSave() }
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

    /// Category filter last used in each city, so leaving and re-entering a
    /// city (the normal rhythm of a day of sightseeing) doesn't reset it.
    @Published var lastCategoryFilter: [String: String] = [:]
    /// Status filter ("Tots"/"Pendents"/"Vistos") last used in each city.
    @Published var lastStatusFilter: [String: String] = [:]

    /// Set when `data.json` is missing, corrupt, or yields zero places, so the
    /// UI can explain what's wrong instead of silently showing an empty app.
    @Published private(set) var loadError: String?
    /// Non-fatal: entries that existed in the file but failed to decode
    /// individually and were skipped (see `decodeResiliently`).
    @Published private(set) var skippedEntryCount = 0

    /// Places per city, pre-sorted by `seq`. Computed once at load instead of
    /// on every call, since `places(for:)` used to be called ~3 times per
    /// home-screen redraw across all 10 cities.
    private var placesByCity: [String: [Place]] = [:]
    /// Visited-count per city, maintained incrementally by `toggleVisited`
    /// instead of recomputed by scanning all places every redraw.
    @Published private(set) var visitedCountByCity: [String: Int] = [:]

    static let visitedKey = "japo_visited_v1"
    static let cityOrderKey = "japo_city_order_v1"
    static let placeOrderKey = "japo_place_order_v1"

    private var saveWorkItem: DispatchWorkItem?

    init() {
        guard let url = Bundle.module.url(forResource: "data", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            self.appData = AppData(cities: [], cityOrder: [], catMeta: [:], catOrder: [], places: [])
            self.visited = []
            self.cityOrder = []
            self.placeOrder = [:]
            self.loadError = "No s'ha trobat el fitxer de dades (data.json) dins de l'aplicació."
            return
        }

        let (decoded, skipped) = Self.decodeResiliently(data)
        self.appData = decoded
        self.skippedEntryCount = skipped
        if decoded.places.isEmpty {
            self.loadError = "El fitxer de dades no s'ha pogut llegir correctament (0 llocs carregats)."
        }

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

        var byCity: [String: [Place]] = [:]
        for p in decoded.places { byCity[p.city, default: []].append(p) }
        for key in byCity.keys { byCity[key]?.sort { $0.seq < $1.seq } }
        self.placesByCity = byCity

        var counts: [String: Int] = [:]
        for (city, list) in byCity {
            counts[city] = list.reduce(0) { $0 + (self.visited.contains($1.id) ? 1 : 0) }
        }
        self.visitedCountByCity = counts
    }

    /// A single malformed entry anywhere in `places`, `cities` or `catMeta`
    /// (a bad type, a missing required field after a future manual edit to
    /// data.json, etc.) used to take down the WHOLE dataset: `JSONDecoder`
    /// fails an array/dictionary as soon as one element doesn't decode. This
    /// decodes every part individually via `FailableDecodable` so one bad
    /// entry anywhere is skipped and logged instead of blanking out the app.
    /// Returns the recovered data plus how many entries were skipped.
    private static func decodeResiliently(_ data: Data) -> (AppData, Int) {
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
            let cityOrder: [String]?
            let catMeta: [String: FailableDecodable<CategoryInfo>]?
            let catOrder: [String]?
            let places: [FailableDecodable<Place>]
        }

        guard let raw = try? JSONDecoder().decode(RawAppData.self, from: data) else {
            // The file isn't even valid JSON / doesn't match the top-level
            // shape at all — nothing to salvage.
            return (AppData(cities: [], cityOrder: [], catMeta: [:], catOrder: [], places: []), 0)
        }
        let places = raw.places.compactMap { $0.base }
        let cities = raw.cities.compactMap { $0.base }
        let catMeta = (raw.catMeta ?? [:]).compactMapValues { $0.base }
        let skipped = (raw.places.count - places.count) + (raw.cities.count - cities.count)
            + ((raw.catMeta?.count ?? 0) - catMeta.count)
        if skipped > 0 {
            print("⚠️ JapoTrip data.json: loaded with \(skipped) malformed entr(y/ies) skipped — the rest of the app still works normally.")
        }
        let appData = AppData(
            cities: cities,
            cityOrder: raw.cityOrder ?? cities.map(\.id),
            catMeta: catMeta,
            catOrder: raw.catOrder ?? Array(catMeta.keys),
            places: places
        )
        return (appData, skipped)
    }

    // MARK: - Visited

    func toggleVisited(_ id: String) {
        guard let place = appData.places.first(where: { $0.id == id }) else { return }
        if visited.contains(id) {
            visited.remove(id)
            visitedCountByCity[place.city, default: 0] -= 1
        } else {
            visited.insert(id)
            visitedCountByCity[place.city, default: 0] += 1
        }
    }

    func isVisited(_ id: String) -> Bool { visited.contains(id) }

    /// Debounces the UserDefaults write so rapidly tapping several "visited"
    /// circles in a row doesn't hit disk synchronously on every tap.
    private func scheduleVisitedSave() {
        saveWorkItem?.cancel()
        let snapshot = Array(visited)
        let work = DispatchWorkItem {
            UserDefaults.standard.set(snapshot, forKey: Self.visitedKey)
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Flushes any pending debounced save immediately — call when the app is
    /// about to background/terminate so a check-in never gets lost.
    func flushPendingSave() {
        guard let work = saveWorkItem else { return }
        work.cancel()
        UserDefaults.standard.set(Array(visited), forKey: Self.visitedKey)
        saveWorkItem = nil
    }

    // MARK: - Export / import (backup, since visited state lives only on this device)

    struct ProgressBackup: Codable {
        let visited: [String]
        let exportedAt: Date
    }

    func exportBackupData() -> Data? {
        let backup = ProgressBackup(visited: Array(visited), exportedAt: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(backup)
    }

    /// Merges (never replaces) an imported backup into the current visited
    /// set, so importing an older backup can't erase newer check-ins.
    @discardableResult
    func importBackupData(_ data: Data) -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(ProgressBackup.self, from: data) else { return 0 }
        let validIds = Set(appData.places.map(\.id))
        let incoming = Set(backup.visited).intersection(validIds)
        let newOnes = incoming.subtracting(visited)
        for id in newOnes { toggleVisited(id) }
        return newOnes.count
    }

    // MARK: - Places

    /// Places for a city in the itinerary's natural (day/seq) order.
    func places(for city: String) -> [Place] {
        placesByCity[city] ?? []
    }

    /// Places for a city honoring any manual drag-to-reorder the user has
    /// done for that city; falls back to the natural order otherwise. New
    /// places that aren't part of a saved custom order (shouldn't normally
    /// happen, but defensive) are appended at the end in natural order.
    func orderedPlaces(for city: String) -> [Place] {
        let natural = places(for: city)
        guard let order = placeOrder[city] else { return natural }
        // `uniquingKeysWith` keeps this safe even if a future manual edit to
        // data.json ever introduces a duplicate id in the same city — it
        // would previously crash the app outright.
        var byId = Dictionary(natural.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
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

    /// All 235 places, in city/seq order — backs the home-screen global search.
    var allPlaces: [Place] { appData.places }

    /// Applies a drag-to-reorder move within a city's place list.
    func movePlaces(in city: String, from source: IndexSet, to destination: Int) {
        var current = orderedPlaces(for: city).map { $0.id }
        current.move(fromOffsets: source, toOffset: destination)
        placeOrder[city] = current
    }

    /// Drops back to the itinerary's original order for one city.
    func resetPlaceOrder(for city: String) {
        placeOrder[city] = nil
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

    /// Drops back to the itinerary's original city order.
    func resetCityOrder() {
        cityOrder = appData.cityOrder
    }

    func cityInfo(_ id: String) -> CityInfo? {
        appData.cities.first { $0.id == id }
    }

    func visitedCount(for city: String) -> Int {
        visitedCountByCity[city] ?? 0
    }

    var totalVisited: Int { visited.count }
    var totalPlaces: Int { appData.places.count }

    /// Must-see places still pending, across the whole trip — feeds the
    /// progress screen.
    var pendingMustSees: [Place] {
        appData.places.filter { $0.isMustSee && !isVisited($0.id) }
            .sorted { ($0.city, $0.seq) < ($1.city, $1.seq) }
    }
}
