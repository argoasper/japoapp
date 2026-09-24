import SwiftUI
import UIKit
import CoreLocation

/// Llista de llocs d'una ciutat (Tots / Pendents / Vistos). S'ordena
/// automàticament per proximitat a la posició actual mentre la pantalla és
/// visible; si no hi ha GPS, mostra l'ordre de l'itinerari.
struct CityPlacesListView: View {
    let cityId: String
    let mode: PlaceListMode
    @EnvironmentObject var store: DataStore
    @StateObject private var locationProvider = LocationProvider()

    @State private var searchText = ""
    @State private var mustSeeOnly = false
    @State private var selectedPlace: Place?
    @State private var isReordering = false
    @State private var mapChoice: MapChoice?
    @State private var useProximity = true

    private var cityInfo: CityInfo? { store.cityInfo(cityId) }
    private var tint: Color { Color(hex: cityInfo?.color ?? "#0071E3") }

    private var selectedCat: String { store.lastCategoryFilter[cityId] ?? "all" }
    private func setSelectedCat(_ v: String) { store.lastCategoryFilter[cityId] = v }

    private var basePlaces: [Place] { store.places(for: cityId, mode: mode) }
    private var canUseProximity: Bool { basePlaces.filter { $0.hasCoords }.count >= 1 }

    private var categories: [(id: String, label: String, icon: String, count: Int)] {
        var counts: [String: Int] = [:]
        for p in basePlaces { for c in p.cats { counts[c, default: 0] += 1 } }
        let ordered = store.appData.catOrder.filter { (counts[$0] ?? 0) > 0 }
        return ordered.compactMap { id in
            guard let meta = store.appData.catMeta[id] else { return nil }
            guard (counts[id] ?? 0) >= 2 else { return nil }
            return (id, meta.label, meta.icon, counts[id] ?? 0)
        }
    }

    private var hasActiveFilters: Bool {
        selectedCat != "all" || mustSeeOnly || !searchText.isEmpty
    }

    private func clearFilters() {
        setSelectedCat("all")
        mustSeeOnly = false
        searchText = ""
    }

    private var filtered: [Place] {
        var list = basePlaces
        if selectedCat != "all" { list = list.filter { $0.cats.contains(selectedCat) } }
        if mustSeeOnly { list = list.filter { $0.isMustSee } }
        if !searchText.isEmpty {
            let q = SearchText.normalize(searchText)
            list = list.filter { SearchText.normalize($0.searchSource).contains(q) }
        }
        return list
    }

    private func distance(to place: Place, from loc: CLLocation) -> CLLocationDistance {
        guard let lat = place.lat, let lng = place.lng else { return .greatestFiniteMagnitude }
        return loc.distance(from: CLLocation(latitude: lat, longitude: lng))
    }

    private func distanceLabel(for place: Place) -> String? {
        guard useProximity, let loc = locationProvider.location, let lat = place.lat, let lng = place.lng else { return nil }
        let d = loc.distance(from: CLLocation(latitude: lat, longitude: lng))
        return d < 1000 ? "\(Int(d)) m" : String(format: "%.1f km", d / 1000)
    }

    /// Quan hi ha posició: llocs amb coordenades ordenats per distància, i els
    /// que no en tenen en una secció a part (mai barrejats).
    private var geoSortedPlaces: (near: [Place], noLocation: [Place])? {
        guard useProximity, let loc = locationProvider.location else { return nil }
        let near = filtered.filter { $0.hasCoords }
            .sorted { (distance(to: $0, from: loc), $0.seq) < (distance(to: $1, from: loc), $1.seq) }
        let far = filtered.filter { !$0.hasCoords }
        return (near, far)
    }

    private var nearestPending: Place? {
        guard let loc = locationProvider.location else { return nil }
        return filtered.filter { $0.hasCoords && !store.isVisited($0.id) }
            .min { distance(to: $0, from: loc) < distance(to: $1, from: loc) }
    }

    var body: some View {
        VStack(spacing: 0) {
            fixedFilterBar
            Divider()
            placesList
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Cerca per nom, adreça, nota…")
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(tint)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mapChoice = MapChoice(
                        title: nearestPending.map { "Com anar a \($0.name)" } ?? "Obre \(cityInfo?.name ?? "la ciutat") als mapes",
                        google: nearestPending.flatMap { MapLinks.googleDirections(to: $0) } ?? cityQueryGoogle,
                        apple: nearestPending.flatMap { MapLinks.appleDirections(to: $0) } ?? cityQueryApple
                    )
                } label: {
                    Image(systemName: "map")
                }
                .accessibilityLabel("Obre als mapes")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        useProximity.toggle()
                        if useProximity { locationProvider.startUpdating() }
                    } label: {
                        Label(useProximity ? "Ordre de l'itinerari" : "Ordena per proximitat",
                              systemImage: useProximity ? "list.number" : "location.fill")
                    }
                    Button {
                        locationProvider.startUpdating()
                    } label: {
                        Label("Actualitza la ubicació", systemImage: "location.circle")
                    }
                    if mode == .all {
                        Divider()
                        Button {
                            withAnimation(.snappy) { isReordering.toggle() }
                            if isReordering { useProximity = false }
                        } label: {
                            Label(isReordering ? "Surt del mode reordenar" : "Reordena els llocs manualment",
                                  systemImage: isReordering ? "checkmark.circle" : "arrow.up.arrow.down")
                        }
                        if store.placeOrder[cityId] != nil {
                            Button(role: .destructive) {
                                store.resetPlaceOrder(for: cityId)
                            } label: {
                                Label("Restaura l'ordre de l'itinerari", systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                } label: {
                    Image(systemName: isReordering ? "checkmark.circle.fill" : "ellipsis.circle")
                }
            }
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailSheet(place: place)
        }
        .mapChoiceDialog($mapChoice)
        .onAppear { if useProximity && canUseProximity { locationProvider.startUpdating() } }
        .onDisappear { locationProvider.stopUpdating() }
    }

    private var cityQueryGoogle: String? {
        guard let name = cityInfo?.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return "https://www.google.com/maps/search/?api=1&query=\(name)+Japan"
    }
    private var cityQueryApple: String? {
        guard let name = cityInfo?.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return "https://maps.apple.com/?q=\(name)+Japan"
    }

    // MARK: - Barra fixa (filtres + estat de la ubicació)

    private var fixedFilterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "Imprescindibles", emoji: "⭐️", isActive: mustSeeOnly, tint: .orange) {
                        mustSeeOnly.toggle()
                    }
                    FilterChip(label: "Totes", emoji: "🏷️", isActive: selectedCat == "all", tint: tint) {
                        setSelectedCat("all")
                    }
                    ForEach(categories, id: \.id) { cat in
                        FilterChip(label: "\(cat.label) \(cat.count)", emoji: cat.icon, isActive: selectedCat == cat.id, tint: tint) {
                            setSelectedCat(cat.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .disabled(isReordering)
            .opacity(isReordering ? 0.35 : 1)

            locationStatusRow
                .padding(.horizontal, 16)

            if hasActiveFilters && !isReordering {
                HStack {
                    Text(activeFilterSummary)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Neteja") { withAnimation(.snappy) { clearFilters() } }
                        .font(.appCaption)
                }
                .padding(.horizontal, 16)
            }

            if isReordering {
                Label("Arrossega ⠿ per canviar l'ordre dels llocs", systemImage: "hand.draw")
                    .font(.appCaption)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ViewBuilder
    private var locationStatusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(useProximity && locationProvider.location != nil ? tint : .secondary)
            Text(statusText)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            if locationProvider.isLocating { ProgressView().controlSize(.small) }
        }
    }

    private var statusIcon: String {
        if !useProximity { return "list.number" }
        if locationProvider.isLocating { return "location.circle" }
        return locationProvider.location != nil ? "location.fill" : "location.slash"
    }

    private var statusText: String {
        if isReordering { return "Mode reordenar (ordre manual)" }
        if !useProximity { return "Ordre de l'itinerari · toca ⋯ per ordenar per proximitat" }
        if !canUseProximity { return "Cap lloc amb coordenades: ordre de l'itinerari" }
        if locationProvider.authDenied { return "Activa la ubicació a Configuració per ordenar per proximitat" }
        if locationProvider.isLocating && locationProvider.location == nil { return "Localitzant…" }
        if let err = locationProvider.errorMessage, locationProvider.location == nil { return err }
        if locationProvider.location != nil {
            let noCoords = filtered.filter { !$0.hasCoords }.count
            var s = locationProvider.reducedAccuracy ? "Ordenat per proximitat (ubicació aproximada)" : "Ordenat per proximitat a tu"
            if noCoords > 0 { s += " · \(noCoords) sense ubicació al final" }
            return s
        }
        return "Ordre de l'itinerari"
    }

    private var activeFilterSummary: String {
        var parts: [String] = []
        if mustSeeOnly { parts.append("Imprescindibles") }
        if selectedCat != "all", let meta = store.appData.catMeta[selectedCat] { parts.append(meta.label) }
        if !searchText.isEmpty { parts.append("\"\(searchText)\"") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Llista

    @ViewBuilder
    private var placesList: some View {
        if isReordering {
            List {
                ForEach(store.orderedPlaces(for: cityId)) { place in
                    PlaceRow(place: place, distanceLabel: nil)
                        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                }
                .onMove { from, to in
                    store.movePlaces(in: cityId, from: from, to: to)
                }
            }
            .environment(\.editMode, .constant(.active))
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        } else {
            List {
                if filtered.isEmpty {
                    emptyState
                } else if let geo = geoSortedPlaces {
                    if !geo.near.isEmpty {
                        Section("Més a prop teu primer (\(geo.near.count))") {
                            ForEach(geo.near) { place in placeRow(place, distance: distanceLabel(for: place)) }
                        }
                    }
                    if !geo.noLocation.isEmpty {
                        Section("Sense ubicació (\(geo.noLocation.count))") {
                            ForEach(geo.noLocation) { place in placeRow(place, distance: nil) }
                        }
                    }
                } else {
                    Section("Ordre de l'itinerari (\(filtered.count))") {
                        ForEach(filtered) { place in placeRow(place, distance: nil) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private func placeRow(_ place: Place, distance: String?) -> some View {
        PlaceRow(place: place, distanceLabel: distance)
            .contentShape(Rectangle())
            .onTapGesture { selectedPlace = place }
            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: mode == .visited ? "checkmark.circle" : "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(emptyMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if hasActiveFilters {
                Button("Neteja els filtres") { withAnimation(.snappy) { clearFilters() } }
                    .buttonStyle(.bordered)
                    .tint(tint)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var emptyMessage: String {
        if hasActiveFilters { return "Cap resultat amb aquests filtres" }
        switch mode {
        case .visited: return "Encara no has marcat cap lloc com a vist en aquesta ciutat"
        case .pending: return "Ho has vist tot! Cap lloc pendent"
        case .all: return "Cap lloc en aquesta ciutat"
        }
    }
}
