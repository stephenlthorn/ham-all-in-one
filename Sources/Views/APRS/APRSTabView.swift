import SwiftUI
import MapKit

struct APRSTabView: View {
    @EnvironmentObject var aprsStore: APRSStore
    @EnvironmentObject var locationService: LocationService
    @State private var searchCallsign = ""
    @State private var showMyStationOnly = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.0, longitude: -77.0),
        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
    )
    @State private var selectedCallsign: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Station list + map split
                List {
                    Section {
                        HStack {
                            TextField("Callsign (e.g. W1AW)", text: $searchCallsign)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.body.monospaced())

                            Button {
                                Task { await aprsStore.lookup(callsign: searchCallsign) }
                            } label: {
                                if aprsStore.isLoading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                            }
                            .disabled(searchCallsign.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        Button("Search Nearby") {
                            Task {
                                if let loc = locationService.currentLatLon {
                                    await aprsStore.searchNearby(lat: loc.lat, lon: loc.lon, radiusKm: 50)
                                }
                            }
                        }
                        .disabled(locationService.currentLatLon == nil)

                        Toggle("My Station Only", isOn: $showMyStationOnly)
                    }

                    if let error = aprsStore.errorMessage {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    Section("Stations (\(displayedStations.count))") {
                        if displayedStations.isEmpty {
                            Text("No stations found")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(displayedStations), id: \.key) { callsign, station in
                                APRSStationRow(station: station)
                                    .onTapGesture {
                                        selectedCallsign = callsign
                                        centerMap(on: station.coordinate)
                                    }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await refreshAll()
                }

                // Map
                Map(coordinateRegion: $mapRegion, annotationItems: mapAnnotations) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        VStack(spacing: 2) {
                            Text(item.callsign)
                                .font(.caption2.monospaced())
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.85))
                                .cornerRadius(4)
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(height: 220)
            }
            .navigationTitle("APRS")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        aprsStore.clear()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private var displayedStations: [(key: String, value: APRSStore.APRSStation)] {
        let all = aprsStore.stations.sorted { $0.key < $1.key }
        if showMyStationOnly {
            return all.filter { $0.key == aprsStore.myStation?.callsign }
        }
        return all
    }

    private var mapAnnotations: [APRSAnnotation] {
        displayedStations.map { APRSAnnotation(callsign: $0.key, coordinate: $0.value.coordinate) }
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }
    }

    private func refreshAll() async {
        await aprsStore.lookup(callsign: searchCallsign)
    }
}

// MARK: - APRS Annotation

struct APRSAnnotation: Identifiable {
    let id = UUID()
    let callsign: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Station Row

struct APRSStationRow: View {
    let station: APRSStore.APRSStation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(station.callsign)
                    .font(.headline.monospaced())
                Spacer()
                if let speed = station.speedKmh, speed > 0 {
                    Label("\(speed) km/h", systemImage: "airplane")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text(String(format: "%.4f, %.4f", station.latitude, station.longitude))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)

                if let alt = station.altitudeM {
                    Text("Alt: \(Int(alt))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(station.source)
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(3)
            }

            if let comment = station.comment, !comment.isEmpty {
                Text(comment)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    APRSTabView()
        .environmentObject(APRSStore())
        .environmentObject(LocationService())
}
