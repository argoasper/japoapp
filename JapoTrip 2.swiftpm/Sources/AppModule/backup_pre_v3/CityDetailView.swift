import SwiftUI
import UIKit
import CoreLocation

struct CityDetailView: View {
    let cityId: String
    @EnvironmentObject var store: DataStore
    @StateObject private var locationProvider = LocationProvider()

    @State private var searchText = ""
    @State private var selectedCat: String = "all"
    @State private var statusFilter: StatusFilter = .all
    @State private var geoActive = false
    @State private var selectedPlace: Place?
    @State private var isReordering = false

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

    private var cityInfo: CityInfo? { store.cityInfo(cityId) }
    private var tint: Color { Color(hex: cityInfo?.color ?? "#0071E3") }
    private var basePlaces: [Place] { store.orderedPlaces(for: cityId) }

    private var categories: [(id: String, label: String, icon: String)] {
        var seen: [String] = []
        for p in basePlaces {
            for c in p.cats where !seen.contains(c) { seen.append(c) }
        }
        let ordered = store.appData.catOrder.filter { seen.contains($0) }
        return ordered.compactMap { id in
            guard let meta = store.appData.catMeta[id] else { return nil }
            return (id, meta.label, meta.icon)
        }
    }

    private var filtered: [Place] {
        var list = basePlaces
        if selectedCat != "all" { list = list.filter { $0.cats.contains(selectedCat) } }
        switch statusFilter {
        case .pending: list = list.filter { !store.isVisited($0.id) }
        case .visited: list = list.filter { store.isVisited($0.id) }
        case .all: break
        }
        if !searchText.isEmpty {
            let q = searchText.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            list = list.filter {
                let hay = ($0.name + " " + $0.desc + " " + $0.address)
                    .folding(options: .diacriticInsensitive, locale: .current).lowercased()
                return hay.contains(q)
            }
        }
        if geoActive, let loc = locationProvider.location {
            list.sort { distance(to: $0, from: loc) < distance(to: $1, from: loc) }
        }
        return list
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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            placesList
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Cerca per nom, adreça…")
        .navigationTitle(cityInfo?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) { isReordering.toggle() }
                } label: {
                    Image(systemName: isReordering ? "checkmark.circle.fill" : "arrow.up.arrow.down")
                }
            }
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailSheet(place: place)
        }
    }

    // MARK: - Fixed header (does not scroll): hero photo, routes, filters,
    // status picker and the proximity button. Only `placesList` below it
    // scrolls independently.

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            heroPhoto

            if let routes = cityInfo?.routes, !routes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ruta completa a Google Maps")
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
                .padding(.horizontal, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "Totes", emoji: "🏷️", isActive: selectedCat == "all", tint: tint) {
                        selectedCat = "all"
                    }
                    ForEach(categories, id: \.id) { cat in
                        FilterChip(label: cat.label, emoji: cat.icon, isActive: selectedCat == cat.id, tint: tint) {
                            selectedCat = cat.id
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .disabled(isReordering)
            .opacity(isReordering ? 0.35 : 1)

            Picker("", selection: $statusFilter) {
                ForEach(StatusFilter.allCases, id: \.self) { s in Text(s.label).tag(s) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .disabled(isReordering)
            .opacity(isReordering ? 0.35 : 1)

            Button {
                if geoActive {
                    geoActive = false
                } else {
                    geoActive = true
                    locationProvider.request()
                }
            } label: {
                HStack {
                    Image(systemName: locationProvider.isLocating ? "location.circle" : "location.fill")
                    Text(geoActive ? "Ordenat per proximitat" : "Ordena per proximitat")
                    Spacer()
                    if locationProvider.isLocating { ProgressView() }
                }
            }
            .buttonStyle(.bordered)
            .tint(geoActive ? tint : .secondary)
            .padding(.horizontal, 16)
            .disabled(isReordering)
            .opacity(isReordering ? 0.35 : 1)

            if locationProvider.authDenied {
                Text("Cal activar la ubicació a Configuració per fer servir \"A prop meu\".")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }

            if isReordering {
                Label("Arrossega ⠿ per canviar l'ordre dels llocs", systemImage: "hand.draw")
                    .font(.appCaption)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 10)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var heroPhoto: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: CityExtras.photoURL(for: cityId), transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .opacity(0.88)
                    case .failure, .empty:
                        LinearGradient(
                            colors: [tint.opacity(0.55), tint.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    @unknown default:
                        tint.opacity(0.3)
                    }
                }
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
                            .font(.appFootnote)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(14)
            }
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - Scrolling content: only the place list moves under the header.

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
                if filtered.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Cap resultat amb aquests filtres")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filtered) { place in
                        PlaceRow(place: place, distanceLabel: distanceLabel(for: place))
                            .contentShape(Rectangle())
                            .onTapGesture { selectedPlace = place }
                            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
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
            .padding(.vertical, 7)
            .background(isActive ? tint : Color(uiColor: .tertiarySystemGroupedBackground))
            .foregroundStyle(isActive ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
