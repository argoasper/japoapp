import SwiftUI
import UIKit

/// Pantalla «Transports» d'una ciutat: aeroports, trajectes entre ciutats
/// i moure's per la zona, amb les estacions de sortida i arribada i un botó
/// per obrir l'itinerari en transport públic a Google Maps o Apple Maps.
struct TransportsView: View {
    let cityId: String
    @EnvironmentObject var store: DataStore
    @State private var mapChoice: MapChoice?
    @State private var expanded: Set<String> = []

    private var cityInfo: CityInfo? { store.cityInfo(cityId) }
    private var tint: Color { Color(hex: cityInfo?.color ?? "#0071E3") }
    private var routes: [TransportRoute] { TransportData.routes(for: cityId) }

    private struct KindGroup: Identifiable {
        let kind: TransportRoute.Kind
        let routes: [TransportRoute]
        var id: String { kind.rawValue }
    }

    private var grouped: [KindGroup] {
        let kinds: [TransportRoute.Kind] = [.airport, .intercity, .local]
        return kinds.compactMap { k in
            let r = routes.filter { $0.kind == k }
            return r.isEmpty ? nil : KindGroup(kind: k, routes: r)
        }
    }

    var body: some View {
        List {
            if routes.isEmpty {
                Text("Encara no hi ha trajectes preparats per a \(cityInfo?.name ?? "aquesta ciutat").")
                    .foregroundStyle(.secondary)
            }
            ForEach(grouped) { group in
                Section(group.kind.rawValue) {
                    ForEach(group.routes) { route in
                        routeCard(route)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    }
                }
            }
            Section {
                Text("Durades aproximades. Comprova sempre l'horari del dia a Google Maps abans de sortir; als trens amb seient reservat (Shinkansen, N'EX, Haruka, Romancecar, Tobu) reserva a la màquina verda o al taulell abans de pujar.")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Transports")
        .navigationBarTitleDisplayMode(.inline)
        .tint(tint)
        .mapChoiceDialog($mapChoice)
    }

    private func routeCard(_ route: TransportRoute) -> some View {
        let isOpen = expanded.contains(route.id)
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) {
                    if isOpen { expanded.remove(route.id) } else { expanded.insert(route.id) }
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.15))
                        Image(systemName: route.icon).foregroundStyle(tint)
                    }
                    .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(route.title)
                            .font(.appSubheadlineBold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(route.summary)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(isOpen ? nil : 2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isOpen {
                ForEach(route.options) { opt in
                    optionRow(opt)
                }
            } else {
                // Tancat: només el primer (millor) trajecte, a un toc.
                if let first = route.options.first {
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.caption2)
                        Text("\(first.name) · \(first.duration)")
                            .font(.appCaption)
                        Spacer()
                        Button("Com anar-hi") {
                            mapChoice = MapChoice(title: "\(first.from) → \(first.to)",
                                                  google: MapLinks.googleTransit(from: first.from, to: first.to),
                                                  apple: MapLinks.appleTransit(from: first.from, to: first.to))
                        }
                        .font(.appCaptionBold)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(tint)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func optionRow(_ opt: TransportRoute.Option) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(opt.name).font(.appSubheadlineBold)
                Spacer()
                if opt.jrPass {
                    Text("JR Pass")
                        .font(.appCaption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.18))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "tram").font(.caption2).foregroundStyle(tint)
                Text(opt.from).font(.appCaption)
                Image(systemName: "arrow.right").font(.caption2)
                Text(opt.to).font(.appCaption)
            }
            .foregroundStyle(.primary)
            Label(opt.duration, systemImage: "clock")
                .font(.appCaption)
                .foregroundStyle(.secondary)
            Text(opt.detail)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button {
                    mapChoice = MapChoice(title: "\(opt.from) → \(opt.to)",
                                          google: MapLinks.googleTransit(from: opt.from, to: opt.to),
                                          apple: MapLinks.appleTransit(from: opt.from, to: opt.to))
                } label: {
                    Label("Com anar-hi", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.appCaptionBold)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(tint)
                Button {
                    let q = opt.from.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? opt.from
                    mapChoice = MapChoice(title: "Estació: \(opt.from)",
                                          google: "https://www.google.com/maps/search/?api=1&query=\(q)",
                                          apple: "https://maps.apple.com/?q=\(q)")
                } label: {
                    Label("Estació de sortida", systemImage: "mappin")
                        .font(.appCaptionBold)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
