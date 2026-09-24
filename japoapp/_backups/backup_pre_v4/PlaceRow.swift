import SwiftUI
import UIKit

enum MapKind {
    case apple, google

    var label: String { self == .apple ? "Apple Maps" : "Google Maps" }
}

/// A small, colorful app-icon-style badge for Apple Maps / Google Maps,
/// drawn in SwiftUI (no bundled image assets needed) so the buttons read as
/// "the real map apps" at a glance instead of a generic monochrome glyph.
struct MapBrandIcon: View {
    let kind: MapKind
    var size: CGFloat = 34

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(background)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .stroke(.black.opacity(kind == .google ? 0.14 : 0.06), lineWidth: kind == .google ? 1 : 0.5)
            )
            .overlay(glyph.padding(size * 0.22))
            .frame(width: size, height: size)
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .apple:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.20, green: 0.78, blue: 0.45), Color(red: 0.09, green: 0.52, blue: 0.94)],
                startPoint: .top, endPoint: .bottom
            ))
        case .google:
            return AnyShapeStyle(Color.white)
        }
    }

    @ViewBuilder
    private var glyph: some View {
        switch kind {
        case .apple:
            Image(systemName: "location.north.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
        case .google:
            Image(systemName: "mappin")
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.26, blue: 0.21),
                            Color(red: 0.98, green: 0.74, blue: 0.02),
                            Color(red: 0.20, green: 0.66, blue: 0.33),
                            Color(red: 0.26, green: 0.52, blue: 0.96),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
    }
}

struct PlaceRow: View {
    let place: Place
    var distanceLabel: String? = nil
    @EnvironmentObject var store: DataStore

    private var isVisited: Bool { store.isVisited(place.id) }
    private var catMeta: CategoryInfo? { store.appData.catMeta[place.cats.first ?? ""] }
    private var tint: Color { Color(hex: place.cityColor) }

    var body: some View {
        Button {
            // Row itself is inert — tapping opens the sheet from
            // CityDetailView, this Button only exists so VoiceOver announces
            // the row as an activatable element with the right label.
        } label: {
            content
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Toca dos cops per obrir la fitxa del lloc")
    }

    private var accessibilitySummary: String {
        var parts = [place.name]
        if place.isMustSee { parts.append("Imprescindible") }
        if let catMeta { parts.append(catMeta.label) }
        if isVisited { parts.append("Visitat") }
        if let distanceLabel { parts.append("a \(distanceLabel)") }
        return parts.joined(separator: ", ")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            if place.isMustSee || distanceLabel != nil {
                HStack(spacing: 6) {
                    if place.isMustSee {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    Spacer()
                    if let distanceLabel {
                        Label(distanceLabel, systemImage: "location.fill")
                            .font(.appCaption2)
                            .foregroundStyle(tint)
                    }
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Text(place.name)
                    .font(.appTitle3)
                    .strikethrough(isVisited, color: .secondary)
                    .foregroundStyle(isVisited ? .secondary : .primary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                if let catMeta {
                    Text(catMeta.label)
                        .font(.appCaption2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .foregroundStyle(tint)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(tint.opacity(0.5), lineWidth: 1)
                        )
                        .fixedSize(horizontal: true, vertical: false)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            if !place.address.isEmpty {
                Label(place.address, systemImage: "mappin")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                MapButton(kind: .apple, urlString: place.apple)
                MapButton(kind: .google, urlString: place.google)
                Spacer()
                Button {
                    withAnimation(.snappy) { store.toggleVisited(place.id) }
                } label: {
                    Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isVisited ? .green : Color(uiColor: .tertiaryLabel))
                }
                .buttonStyle(.plain)
                .tapTarget(44)
                .accessibilityLabel(isVisited ? "Marcat com a vist" : "Marcar com a vist")
                .accessibilityAddTraits(isVisited ? [.isSelected] : [])
            }
        }
        // Only the checkmark fades when visited — keeping the name at full
        // contrast (instead of dimming the whole card) keeps it legible
        // outdoors, where re-reading a visited place's notes is common.
        .padding(.vertical, 6)
    }
}

struct MapButton: View {
    let kind: MapKind
    let urlString: String?

    var body: some View {
        Button {
            guard let urlString, let url = URL(string: urlString) else { return }
            UIApplication.shared.open(url)
        } label: {
            MapBrandIcon(kind: kind, size: 34)
        }
        .buttonStyle(.plain)
        .tapTarget(44)
        .disabled(urlString == nil)
        .opacity(urlString == nil ? 0.35 : 1)
        .accessibilityLabel(kind.label)
        .accessibilityHint(urlString == nil ? "No disponible" : "Obre la ubicació a \(kind.label)")
    }
}
