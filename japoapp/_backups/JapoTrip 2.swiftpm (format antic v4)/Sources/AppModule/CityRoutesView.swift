import SwiftUI
import UIKit
import CoreLocation

// MARK: - Càlcul de la ruta per proximitat

/// Construeix un trajecte que uneix tots els punts d'una ciutat pel veí més
/// proper (començant per la posició actual, si es té) i el millora amb
/// 2-opt perquè no hi hagi creuaments. Distàncies en línia recta (haversine
/// via CoreLocation): prou bo per decidir «on vaig ara».
enum RouteBuilder {
    struct Stop: Identifiable, Hashable {
        let place: Place
        /// Distància des de la parada anterior (o des de la posició actual
        /// per a la primera), en metres.
        let legMeters: Double
        var id: String { place.id }
    }

    static func build(places: [Place], from origin: CLLocation?) -> [Stop] {
        let pts = places.filter { $0.hasCoords }
        guard !pts.isEmpty else { return [] }
        let locs = pts.map { CLLocation(latitude: $0.lat!, longitude: $0.lng!) }
        let n = pts.count

        // Matriu de distàncies (n ≤ ~60 per ciutat: trivial).
        var d = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n { for j in (i + 1)..<n where j < n {
            let v = locs[i].distance(from: locs[j])
            d[i][j] = v; d[j][i] = v
        } }

        // Punt de partida: el més proper a l'usuari, o el primer de l'itinerari.
        var start = 0
        if let origin {
            start = (0..<n).min { origin.distance(from: locs[$0]) < origin.distance(from: locs[$1]) } ?? 0
        }

        // Veí més proper.
        var order = [start]
        var remaining = Set(0..<n); remaining.remove(start)
        while !remaining.isEmpty {
            let last = order.last!
            let next = remaining.min { d[last][$0] < d[last][$1] }!
            order.append(next); remaining.remove(next)
        }

        // 2-opt (camí obert: no es tanca cap al principi).
        if n >= 4 {
            var improved = true
            var rounds = 0
            while improved && rounds < 50 {
                improved = false; rounds += 1
                for i in 1..<(n - 1) {
                    for j in (i + 1)..<n {
                        let a = order[i - 1], b = order[i], c = order[j]
                        let e = (j + 1 < n) ? order[j + 1] : nil
                        let before = d[a][b] + (e.map { d[c][$0] } ?? 0)
                        let after = d[a][c] + (e.map { d[b][$0] } ?? 0)
                        if after + 1 < before {
                            order[i...j].reverse()
                            improved = true
                        }
                    }
                }
            }
        }

        var stops: [Stop] = []
        for (k, idx) in order.enumerated() {
            let leg: Double
            if k == 0 { leg = origin.map { $0.distance(from: locs[idx]) } ?? 0 }
            else { leg = d[order[k - 1]][idx] }
            stops.append(Stop(place: pts[idx], legMeters: leg))
        }
        return stops
    }

    static func format(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1000)
    }

    /// Trams de com a màxim 10 parades (límit de Google Maps per URL).
    static func chunks<T>(_ items: [T], size: Int = 10) -> [[T]] {
        guard !items.isEmpty else { return [] }
        var result: [[T]] = []
        var i = 0
        while i < items.count {
            // Cada tram comença on acaba l'anterior perquè la ruta sigui contínua.
            let end = min(i + size, items.count)
            result.append(Array(items[i..<end]))
            if end == items.count { break }
            i = end - 1
        }
        return result
    }
}

// MARK: - Pantalla «Mapes i Rutes»

struct CityRoutesView: View {
    let cityId: String
    @EnvironmentObject var store: DataStore
    @StateObject private var locationProvider = LocationProvider()

    @State private var onlyPending = false
    @State private var mapChoice: MapChoice?
    @State private var selectedPlace: Place?
    @State private var tramChoice: [[Place]]?

    private var cityInfo: CityInfo? { store.cityInfo(cityId) }
    private var tint: Color { Color(hex: cityInfo?.color ?? "#0071E3") }

    private var candidates: [Place] {
        let base = store.orderedPlaces(for: cityId)
        return onlyPending ? base.filter { !store.isVisited($0.id) } : base
    }
    private var noCoordsCount: Int { candidates.filter { !$0.hasCoords }.count }

    /// Es recalcula només quan canvia alguna entrada (posició, filtre,
    /// vistos), no a cada redibuix: el 2-opt sobre 50 punts no és gratuït.
    @State private var stops: [RouteBuilder.Stop] = []

    private func recompute() {
        stops = RouteBuilder.build(places: candidates, from: locationProvider.location)
    }
    private var totalMeters: Double { stops.reduce(0) { $0 + $1.legMeters } }
    private var walkingTime: String {
        let minutes = Int((totalMeters / 4200.0 * 60).rounded())  // ~4,2 km/h
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }

    var body: some View {
        List {
            Section {
                summaryCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if stops.isEmpty {
                Section {
                    Text("Cap lloc amb coordenades per traçar una ruta.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        stopRow(index: index, stop: stop)
                    }
                } header: {
                    Text("Trajecte per proximitat · \(stops.count) parades")
                } footer: {
                    if noCoordsCount > 0 {
                        Text("\(noCoordsCount) llocs sense coordenades no s'inclouen a la ruta.")
                    }
                }
            }

            if let routes = cityInfo?.routes, !routes.isEmpty {
                Section("Rutes temàtiques preparades") {
                    ForEach(routes) { route in
                        Button {
                            mapChoice = MapChoice(title: route.label.replacingOccurrences(of: "🗺️ ", with: ""),
                                                  google: route.url, apple: nil)
                        } label: {
                            HStack {
                                Image(systemName: "map.fill").foregroundStyle(tint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(route.label.replacingOccurrences(of: "🗺️ ", with: ""))
                                        .font(.appSubheadline)
                                        .foregroundStyle(.primary)
                                    Text("\(route.stops) parades · Google Maps")
                                        .font(.appCaption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.appCaption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Mapes i Rutes")
        .navigationBarTitleDisplayMode(.inline)
        .tint(tint)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    locationProvider.request()
                } label: {
                    Image(systemName: locationProvider.location == nil ? "location" : "location.fill")
                }
                .accessibilityLabel("Actualitza la ubicació")
            }
        }
        .sheet(item: $selectedPlace) { place in PlaceDetailSheet(place: place) }
        .mapChoiceDialog($mapChoice)
        .confirmationDialog("Google Maps admet 10 parades per ruta: tria el tram",
                            isPresented: Binding(get: { tramChoice != nil }, set: { if !$0 { tramChoice = nil } }),
                            titleVisibility: .visible,
                            presenting: tramChoice) { parts in
            ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                Button("Tram \(i + 1)/\(parts.count) · parades \(i * 9 + 1)-\(i * 9 + part.count)") {
                    MapLinks.open(MapLinks.googleRoute(part))
                }
            }
            if let first = parts.first?.first {
                Button("Apple Maps: fins a la primera parada") {
                    MapLinks.open(MapLinks.appleLeg(from: nil, to: first))
                }
            }
            Button("Cancel·la", role: .cancel) {}
        } message: { parts in
            Text("Cada tram comença on acaba l'anterior (\(parts.count) trams).")
        }
        .onAppear {
            recompute()
            locationProvider.request()
        }
        .onChange(of: onlyPending) { _, _ in recompute() }
        .onChange(of: locationProvider.location) { _, _ in recompute() }
        .onChange(of: store.visited) { _, _ in recompute() }
        .onChange(of: store.placeOrder) { _, _ in recompute() }
    }

    // MARK: - Resum + botons d'obrir la ruta

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ruta que uneix tots els punts")
                        .font(.appSubheadlineBold)
                    Text(startText)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if locationProvider.isLocating { ProgressView().controlSize(.small) }
            }

            HStack(spacing: 18) {
                statTile(value: "\(stops.count)", label: "parades")
                statTile(value: RouteBuilder.format(totalMeters), label: "en línia recta")
                statTile(value: walkingTime, label: "a peu aprox.")
            }

            Toggle(isOn: $onlyPending) {
                Label("Només llocs pendents", systemImage: "circle")
                    .font(.appSubheadline)
            }
            .tint(tint)

            HStack(spacing: 10) {
                Button {
                    openWholeRoute()
                } label: {
                    Label("Obre la ruta", systemImage: "map.fill")
                        .font(.appSubheadlineBold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .disabled(stops.count < 2)

                if let first = stops.first {
                    Button {
                        mapChoice = MapChoice(title: "Fins a \(first.place.name)",
                                              google: MapLinks.googleDirections(to: first.place),
                                              apple: MapLinks.appleDirections(to: first.place))
                    } label: {
                        Label("Primera parada", systemImage: "figure.walk")
                            .font(.appSubheadlineBold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(tint)
                }
            }
        }
        .padding(14)
        .softCard(tint: tint)
    }

    private var startText: String {
        if locationProvider.authDenied { return "Sense permís d'ubicació: comença pel primer lloc de l'itinerari" }
        if locationProvider.location != nil { return "Comença pel lloc més proper a on ets ara" }
        if locationProvider.isLocating { return "Localitzant per començar pel lloc més proper…" }
        return "Comença pel primer lloc de l'itinerari (sense GPS)"
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.app(18)).monospacedDigit()
            Text(label).font(.appCaption2).foregroundStyle(.secondary)
        }
    }

    /// Google Maps admet 10 punts per URL: si la ruta és més llarga, es
    /// pregunta quin tram obrir. Apple Maps només fa una destinació.
    private func openWholeRoute() {
        let places = stops.map(\.place)
        let parts = RouteBuilder.chunks(places, size: 10)
        if parts.count == 1 {
            mapChoice = MapChoice(title: "Obre la ruta sencera",
                                  google: MapLinks.googleRoute(places),
                                  apple: MapLinks.appleLeg(from: nil, to: places[0]))
        } else {
            tramChoice = parts
        }
    }

    // MARK: - Files

    private func stopRow(index: Int, stop: RouteBuilder.Stop) -> some View {
        let visited = store.isVisited(stop.place.id)
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(visited ? Color.green : tint)
                Text("\(index + 1)")
                    .font(.app(13))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(stop.place.name)
                    .font(.appSubheadlineBold)
                    .strikethrough(visited, color: .secondary)
                    .foregroundStyle(visited ? .secondary : .primary)
                HStack(spacing: 6) {
                    Image(systemName: index == 0 ? "location.fill" : "arrow.turn.down.right")
                        .font(.caption2)
                    Text(index == 0
                         ? (locationProvider.location != nil ? "a \(RouteBuilder.format(stop.legMeters)) d'on ets" : "inici de la ruta")
                         : "\(RouteBuilder.format(stop.legMeters)) des de l'anterior")
                }
                .font(.appCaption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                let prev = index > 0 ? stops[index - 1].place : nil
                mapChoice = MapChoice(title: "Fins a \(stop.place.name)",
                                      google: MapLinks.googleDirections(to: stop.place),
                                      apple: MapLinks.appleLeg(from: prev, to: stop.place))
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(tint)
            }
            .buttonStyle(.plain)
            .tapTarget(44)
            .accessibilityLabel("Com anar-hi")
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedPlace = stop.place }
    }
}
