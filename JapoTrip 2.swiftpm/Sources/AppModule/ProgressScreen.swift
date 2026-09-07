import SwiftUI

/// A trip-wide progress screen — how far along each city is and which
/// hand-curated "must-see" places are still pending — since the only global
/// signal used to be a single "X of 235" line with nothing to act on.
struct ProgressScreen: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlace: Place?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.cityOrder, id: \.self) { cityId in
                        if let info = store.cityInfo(cityId) {
                            let total = store.places(for: cityId).count
                            let visited = store.visitedCount(for: cityId)
                            HStack {
                                Text(info.icon)
                                Text(info.name)
                                Spacer()
                                Text("\(visited)/\(total)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                ProgressBar(progress: total == 0 ? 0 : Double(visited) / Double(total), tint: Color(hex: info.color))
                                    .frame(width: 60, height: 6)
                            }
                            .font(.appSubheadline)
                        }
                    }
                } header: {
                    Text("Progrés per ciutat")
                }

                let pending = store.pendingMustSees
                if !pending.isEmpty {
                    Section {
                        ForEach(pending) { place in
                            Button {
                                selectedPlace = place
                            } label: {
                                HStack {
                                    Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(place.name).foregroundStyle(.primary)
                                        Text(place.cityName).font(.appCaption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    } header: {
                        Text("Imprescindibles pendents (\(pending.count))")
                    }
                } else {
                    Section {
                        Label("Has visitat tots els imprescindibles!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Progrés del viatge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tanca") { dismiss() }
                }
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailSheet(place: place)
            }
        }
    }
}

struct ProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.18))
                Capsule().fill(tint).frame(width: max(0, geo.size.width) * min(max(progress, 0), 1))
            }
        }
        .clipShape(Capsule())
    }
}
