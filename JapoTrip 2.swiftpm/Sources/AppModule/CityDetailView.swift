import SwiftUI
import UIKit
import CoreLocation

struct CityDetailView: View {
    let cityId: String
    @EnvironmentObject var store: DataStore
    @StateObject private var locationProvider = LocationProvider()

    @State private var searchText = ""
    @State private var mustSeeOnly = false
    @State private var dayFilter: String? = nil
    @State private var geoActive = false
    @State private var selectedPlace: Place?
    @State private var isReordering = false

    @ScaledMetric(relativeTo: .body) private var heroHeight: CGFloat = 130

    enum StatusFilter: String, CaseIterable {
        case all, pending, visited
        var label: String {
            switch self {
            case .all: return "Tots"
            case .pending: return "Pendents"
            case .visited: return "Vistos"
            }
        }
    }

    private var selectedCat: String {
        get { store.lastCategoryFilter[cityId] ?? "all" }
    }
    private func setSelectedCat(_ v: String) { store.lastCategoryFilter[cityId] = v }

    private var statusFilter: StatusFilter {
        StatusFilter(rawValue: store.lastStatusFilter[cityId] ?? "all") ?? .all
    }
    private func setStatusFilter(_ v: StatusFilter) { store.lastStatusFilter[cityId] = v.rawValue }

    private var cityInfo: CityInfo? { store.cityInfo(cityId) }
    private var tint: Color { Color(hex: cityInfo?.color ?? "#0071E3") }
    private var basePlaces: [Place] { store.orderedPlaces(for: cityId) }
    private var geoEligiblePlaces: [Place] { basePlaces.filter { $0.hasCoords } }
    private var canUseProximity: Bool { geoEligiblePlaces.count >= 2 }

    private var categories: [(id: String, label: String, icon: String, count: Int)] {
        var counts: [String: Int] = [:]
        for p in basePlaces { for c in p.cats { counts[c, default: 0] += 1 } }
        let ordered = store.appData.catOrder.filter { (counts[$0] ?? 0) > 0 }
        return ordered.compactMap { id in
            guard let meta = store.appData.catMeta[id] else { return nil }
            // Categories with a single place aren't worth their own chip in a
            // small city — they only add clutter to an already tight header.
            guard (counts[id] ?? 0) >= 2 else { return nil }
            return (id, meta.label, meta.icon, counts[id] ?? 0)
        }
    }

    /// Distinct itinerary days for this city, in the order they first appear
    /// (i.e. chronological order), each with its place count.
    private var days: [(day: String, count: Int)] {
        var seen: [String] = []
        var counts: [String: Int] = [:]
        for p in basePlaces where !p.day.isEmpty {
            if counts[p.day] == nil { seen.append(p.day) }
            counts[p.day, default: 0] += 1
        }
        return seen.map { ($0, counts[$0] ?? 0) }
    }

    private var hasActiveFilters: Bool {
        selectedCat != "all" || statusFilter != .all || mustSeeOnly || dayFilter != nil || !searchText.isEmpty
    }

    private func clearFilters() {
        setSelectedCat("all")
        setStatusFilter(.all)
        mustSeeOnly = false
        dayFilter = nil
        searchText = ""
    }

    private var filtered: [Place] {
        var list = basePlaces
        if selectedCat != "all" { list = list.filter { $0.cats.contains(selectedCat) } }
        if mustSeeOnly { list = list.filter { $0.isMustSee } }
        if let dayFilter { list = list.filter { $0.day == dayFilter } }
        switch statusFilter {
        case .pending: list = list.filter { !store.isVisited($0.id) }
        case .visited: list = list.filter { store.isVisited($0.id) }
        case .all: break
        }
        if !searchText.isEmpty {
            let q = SearchText.normalize(searchText)
            list = list.filter { SearchText.normalize($0.searchSource).contains(q) }
        }
        return list
    }

    /// Places grouped by day, in itinerary order — used when proximity
    /// sorting is off, so "what's on today" stays the default reading order.
    private var groupedByDay: [(day: String, places: [Place])] {
        var order: [String] = []
        var buckets: [String: [Place]] = [:]
        for p in filtered {
            let key = p.day.isEmpty ? "—" : p.day
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(p)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    private func distance(to place: Place, from loc: CLLocation) -> CLLocationDistance {
        guard let lat = place.lat, let lng = place.lng else { return .greatestFiniteMagnitude }
        return loc.distance(from: CLLocation(latitude: lat, longitude: lng))
    }

    private func distanceLabel(for place: Place) -> String? {
        guard geoActive, let loc = locationProvider.location, let lat = place.lat, let lng = place.lng else { return nil }
        let d = loc.distance(from: CLLocation(latitude: lat, longitude: lng))
        return d < 1000 ? "\(Int(d)) m" : String(format: "%.1f km", d / 1000)
    }

    /// When proximity is active, split into places we CAN sort by distance
    /// and those we can't — instead of silently mixing an arbitrary tail of
    /// no-coordinate places into a list that claims to be distance-sorted.
    private var geoSortedPlaces: (near: [Place], noLocation: [Place])? {
        guard geoActive, let loc = locationProvider.location else { return nil }
        let near = filtered.filter { $0.hasCoords }
            .sorted { (distance(to: $0, from: loc), $0.seq) < (distance(to: $1, from: loc), $1.seq) }
        let far = filtered.filter { !$0.hasCoords }
        return (near, far)
    }

    var body: some View {
        VStack(spacing: 0) {
            fixedFilterBar
            Divider()
            placesList
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Cerca per nom, adreça, nota…")
        .navigationTitle(cityInfo?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .tint(tint)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        withAnimation(.snappy) { isReordering.toggle() }
                    } label: {
                        Label(isReordering ? "Surt del mode reordenar" : "Reordena els llocs",
                              systemImage: isReordering ? "checkmark.circle" : "arrow.up.arrow.down")
                    }
                    if store.placeOrder[cityId] != nil {
                        Button(role: .destructive) {
                            store.resetPlaceOrder(for: cityId)
                        } label: {
                            Label("Restaura l'ordre de l'itinerari", systemImage: "arrow.counterclockwise")
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
    }

    // MARK: - Fixed bar: only the controls used *while* scrolling stay pinned
    // (category/day chips + status picker). The hero photo and route buttons
    // now scroll away with the list — on a small phone they used to eat
    // almost the whole screen before a single place was visible.

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

            if days.count > 1 {
                dayMenu
                    .padding(.horizontal, 16)
                    .disabled(isReordering)
                    .opacity(isReordering ? 0.35 : 1)
            }

            Picker("", selection: Binding(get: { statusFilter }, set: { setStatusFilter($0) })) {
                ForEach(StatusFilter.allCases, id: \.self) { s in Text(s.label).tag(s) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .disabled(isReordering)
            .opacity(isReordering ? 0.35 : 1)

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

    private var dayMenu: some View {
        Menu {
            Button {
                dayFilter = nil
            } label: {
                if dayFilter == nil { Label("Tots els dies", systemImage: "checkmark") }
                else { Text("Tots els dies") }
            }
            ForEach(days, id: \.day) { entry in
                Button {
                    dayFilter = entry.day
                } label: {
                    if dayFilter == entry.day { Label("\(entry.day) (\(entry.count))", systemImage: "checkmark") }
                    else { Text("\(entry.day) (\(entry.count))") }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(dayFilter ?? "Tots els dies")
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                Spacer()
            }
            .font(.appSubheadline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var activeFilterSummary: String {
        var parts: [String] = []
        if mustSeeOnly { parts.append("Imprescindibles") }
        if selectedCat != "all", let meta = store.appData.catMeta[selectedCat] { parts.append(meta.label) }
        if let dayFilter { parts.append(dayFilter) }
        if statusFilter != .all { parts.append(statusFilter.label) }
        if !searchText.isEmpty { parts.append("\"\(searchText)\"") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Header content (now scrolls with the list)

    @ViewBuilder
    private var headerRows: some View {
        heroPhoto
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

        if let routes = cityInfo?.routes, !routes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Rutes a Google Maps")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                ForEach(routes) { route in
                    Button {
                        if let url = URL(string: route.url) { UIApplication.shared.open(url) }
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                            VStack(alignment: .leading, spacing: 1) {
                                Text(route.label.replacingOccurrences(of: "🗺️ ", with: ""))
                                    .font(.appSubheadline)
                                Text("\(route.stops) parades amb nom")
                                    .font(.appCaption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.appCaption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(tint)
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }

        proximityRow
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var proximityRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                if geoActive {
                    geoActive = false
                    locationProvider.cancel()
                } else {
                    geoActive = true
                    locationProvider.request()
                }
            } label: {
                HStack {
                    Image(systemName: locationProvider.isLocating ? "location.circle" : "location.fill")
                    Text(proximityButtonLabel)
                    Spacer()
                    if locationProvider.isLocating { ProgressView() }
                }
            }
            .buttonStyle(.bordered)
            .tint(geoActive ? tint : .secondary)
            .disabled(!canUseProximity)
            .opacity(canUseProximity ? 1 : 0.5)

            if !canUseProximity {
                Text("Sense coordenades fiables per a cap lloc d'aquesta ciutat.")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            } else if locationProvider.authDenied {
                Text("Cal activar la ubicació a Configuració per fer servir \"A prop meu\".")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            } else if let error = locationProvider.errorMessage {
                Text(error)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            } else if locationProvider.reducedAccuracy && geoActive {
                Text("Ubicació aproximada activada: l'ordre pot no ser exacte.")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            } else if geoActive && geoEligiblePlaces.count < basePlaces.count {
                Text("\(basePlaces.count - geoEligiblePlaces.count) llocs sense coordenades es mostren sense ordenar, en secció apart.")
                    .font(.appCaption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var proximityButtonLabel: String {
        if !canUseProximity { return "Sense coordenades en aquesta ciutat" }
        if locationProvider.isLocating { return "Localitzant…" }
        if geoActive && locationProvider.location != nil { return "Ordenat per proximitat" }
        return "Ordena per proximitat"
    }

    // MARK: - Scrolling content

    @ViewBuilder
    private var placesList: some View {
        if isReordering {
            // Reorder mode: always the full, unfiltered list in its current
            // (possibly already custom) order, with native drag handles.
            List {
                ForEach(basePlaces) { place in
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
                headerRows

                if filtered.isEmpty {
                    emptyState
                } else if let geo = geoSortedPlaces {
                    if !geo.near.isEmpty {
                        Section("Ordenats per distància (\(geo.near.count))") {
                            ForEach(geo.near) { place in placeRow(place, distance: distanceLabel(for: place)) }
                        }
                    }
                    if !geo.noLocation.isEmpty {
                        Section("Sense ubicació (\(geo.noLocation.count))") {
                            ForEach(geo.noLocation) { place in placeRow(place, distance: nil) }
                        }
                    }
                } else if dayFilter == nil && days.count > 1 {
                    ForEach(groupedByDay, id: \.day) { group in
                        Section(group.day) {
                            ForEach(group.places) { place in placeRow(place, distance: nil) }
                        }
                    }
                } else {
                    ForEach(filtered) { place in placeRow(place, distance: nil) }
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
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Cap resultat amb aquests filtres")
                .foregroundStyle(.secondary)
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

    private var heroPhoto: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                CityHeroImage(cityId: cityId, tint: tint)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.22), .black.opacity(0.48)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cityInfo?.name ?? "")
                        .font(.app(22))
                        .foregroundStyle(.white)
                    let ja = CityExtras.nameJa(for: cityId)
                    if !ja.isEmpty {
                        Text(ja)
                            .font(.appJapanese(13))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(14)
            }
        }
        .frame(height: heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

struct FilterChip: View {
    let label: String
    let emoji: String
    let isActive: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(emoji)
                Text(label).font(.appSubheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isActive ? tint : Color(uiColor: .tertiarySystemGroupedBackground))
            .foregroundStyle(isActive ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .tapTarget(40)
    }
}
