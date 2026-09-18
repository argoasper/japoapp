import SwiftUI
import UIKit

/// Pantalla d'una ciutat (v4): foto de capçalera + cinc «caixes» a l'estil de
/// l'app Recordatoris (Mapes i Rutes · Tots els llocs · Llocs pendents ·
/// Llocs vistos · Transports). Cada caixa obre la seva pròpia pantalla; les
/// llistes de llocs s'ordenen automàticament per proximitat GPS.
struct CityDetailView: View {
    let cityId: String
    @EnvironmentObject var store: DataStore

    @ScaledMetric(relativeTo: .body) private var heroHeight: CGFloat = 150

    private var cityInfo: CityInfo? { store.cityInfo(cityId) }
    private var tint: Color { Color(hex: cityInfo?.color ?? "#0071E3") }
    private var total: Int { store.places(for: cityId).count }
    private var visited: Int { store.visitedCount(for: cityId) }
    private var pending: Int { total - visited }
    private var withCoords: Int { store.places(for: cityId).filter { $0.hasCoords }.count }
    private var transportCount: Int { TransportData.routes(for: cityId).count }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroPhoto

                LazyVGrid(columns: columns, spacing: 14) {
                    NavigationLink(value: CityScreen.routes(city: cityId)) {
                        ReminderBox(title: "Mapes i Rutes", icon: "map.fill", color: .blue,
                                    count: withCoords, subtitle: "\(withCoords) punts al mapa")
                    }
                    NavigationLink(value: CityScreen.places(city: cityId, mode: .all)) {
                        ReminderBox(title: "Tots els llocs", icon: "tray.full.fill", color: Color(uiColor: .systemGray),
                                    count: total, subtitle: "ordenats per proximitat")
                    }
                    NavigationLink(value: CityScreen.places(city: cityId, mode: .pending)) {
                        ReminderBox(title: "Llocs pendents", icon: "circle", color: .orange,
                                    count: pending, subtitle: pending == 0 ? "tot vist!" : "per visitar")
                    }
                    NavigationLink(value: CityScreen.places(city: cityId, mode: .visited)) {
                        ReminderBox(title: "Llocs vistos", icon: "checkmark.circle.fill", color: .green,
                                    count: visited, subtitle: visited == 0 ? "encara cap" : "ja visitats")
                    }
                    NavigationLink(value: CityScreen.transports(city: cityId)) {
                        ReminderBox(title: "Transports", icon: "tram.fill", color: .purple,
                                    count: transportCount, subtitle: "trajectes i estacions")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                progressCard
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(cityInfo?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .tint(tint)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Progrés a \(cityInfo?.name ?? "")", systemImage: "checkmark.seal.fill")
                    .font(.appSubheadlineBold)
                Spacer()
                Text("\(visited) / \(total)")
                    .font(.appSubheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressBar(progress: total == 0 ? 0 : Double(visited) / Double(total), tint: tint)
                .frame(height: 8)
        }
        .padding(14)
        .softCard(tint: tint)
    }

    private var heroPhoto: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                CityHeroImage(cityId: cityId, tint: tint)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.22), .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cityInfo?.name ?? "")
                        .font(.app(24))
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

/// Una caixa a l'estil de les de l'app Recordatoris: icona dins d'un cercle
/// de color a dalt a l'esquerra, número gros a la dreta i títol a sota.
struct ReminderBox: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    var subtitle: String = ""

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().fill(color)
                    Image(systemName: icon)
                        .font(.system(size: iconSize * 0.5, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: iconSize, height: iconSize)
                Spacer()
                Text("\(count)")
                    .font(.app(28))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appSubheadlineBold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.appCaption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .tapTarget(60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count)")
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

// MARK: - Obrir mapes (diàleg Google / Apple)

enum MapLinks {
    static func open(_ urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    /// Cerca d'un lloc pel nom (o per coordenades si en té).
    static func google(place: Place) -> String? {
        if let lat = place.lat, let lng = place.lng {
            return "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)"
        }
        return place.google
    }
    static func apple(place: Place) -> String? {
        if let lat = place.lat, let lng = place.lng {
            let name = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "https://maps.apple.com/?ll=\(lat),\(lng)&q=\(name)"
        }
        return place.apple
    }

    /// Indicacions a peu des de la posició actual fins al lloc.
    static func googleDirections(to place: Place) -> String? {
        if let lat = place.lat, let lng = place.lng {
            return "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)&travelmode=walking"
        }
        guard let q = place.google?.split(separator: "=").last else { return nil }
        return "https://www.google.com/maps/dir/?api=1&destination=\(q)&travelmode=walking"
    }
    static func appleDirections(to place: Place) -> String? {
        if let lat = place.lat, let lng = place.lng {
            return "https://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=w"
        }
        guard let q = place.apple?.split(separator: "=").last else { return nil }
        return "https://maps.apple.com/?daddr=\(q)&dirflg=w"
    }

    /// Ruta de Google Maps amb diversos punts (màx. 10 per URL: origen +
    /// 8 punts intermedis + destinació).
    static func googleRoute(_ stops: [Place], walking: Bool = true) -> String? {
        let pts = stops.compactMap { p -> String? in
            guard let lat = p.lat, let lng = p.lng else { return nil }
            return "\(lat),\(lng)"
        }
        guard pts.count >= 2 else { return nil }
        var url = "https://www.google.com/maps/dir/?api=1&origin=\(pts.first!)&destination=\(pts.last!)"
        let mid = pts.dropFirst().dropLast()
        if !mid.isEmpty { url += "&waypoints=" + mid.joined(separator: "%7C") }
        url += walking ? "&travelmode=walking" : "&travelmode=transit"
        return url
    }

    /// Apple Maps només admet origen i destinació: indicacions d'un punt al
    /// següent.
    static func appleLeg(from a: Place?, to b: Place) -> String? {
        guard let lat = b.lat, let lng = b.lng else { return nil }
        var url = "https://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=w"
        if let a, let alat = a.lat, let alng = a.lng { url += "&saddr=\(alat),\(alng)" }
        return url
    }

    /// Indicacions en transport públic entre dues estacions (per nom).
    static func googleTransit(from: String, to: String) -> String {
        let f = from.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? from
        let t = to.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? to
        return "https://www.google.com/maps/dir/?api=1&origin=\(f)&destination=\(t)&travelmode=transit"
    }
    static func appleTransit(from: String, to: String) -> String {
        let f = from.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? from
        let t = to.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? to
        return "https://maps.apple.com/?saddr=\(f)&daddr=\(t)&dirflg=r"
    }
}

/// Diàleg reutilitzable «Obre a Google Maps / Apple Maps».
struct MapChoice: Identifiable {
    let id = UUID()
    let title: String
    let google: String?
    let apple: String?
}

struct MapChoiceDialog: ViewModifier {
    @Binding var choice: MapChoice?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            choice?.title ?? "Obre a…",
            isPresented: Binding(get: { choice != nil }, set: { if !$0 { choice = nil } }),
            titleVisibility: .visible,
            presenting: choice
        ) { c in
            if let g = c.google {
                Button("Google Maps") { MapLinks.open(g) }
            }
            if let a = c.apple {
                Button("Apple Maps") { MapLinks.open(a) }
            }
            Button("Cancel·la", role: .cancel) {}
        } message: { _ in
            Text("Tria l'app de mapes")
        }
    }
}

extension View {
    func mapChoiceDialog(_ choice: Binding<MapChoice?>) -> some View {
        modifier(MapChoiceDialog(choice: choice))
    }
}
