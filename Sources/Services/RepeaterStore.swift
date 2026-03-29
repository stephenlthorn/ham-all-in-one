import Foundation
import CoreLocation
import Combine

// MARK: - Repeater Store

@MainActor
final class RepeaterStore: ObservableObject {
    @Published private(set) var repeaters: [Repeater] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var searchQuery = ""
    @Published var selectedBand: RepeaterBand?
    @Published var sortOrder: SortOrder = .distance

    enum SortOrder {
        case distance, frequency, callsign, tone
    }

    private let fileManager = FileManager.default

    init() {
        loadFromBundledDB()
    }

    // MARK: - Load bundled RepeaterBook data

    private func loadFromBundledDB() {
        guard let url = Bundle.main.url(forResource: "repeaters", withExtension: "json") else {
            // No bundled DB — use sample data for now
            loadSampleData()
            return
        }

        isLoading = true
        Task {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([Repeater].self, from: data)
                self.repeaters = decoded
            } catch {
                self.errorMessage = "Failed to load repeater DB: \(error)"
                self.loadSampleData()
            }
            self.isLoading = false
        }
    }

    private func loadSampleData() {
        // Sample data for demo — real app uses bundled RepeaterBook SQLite export
        repeaters = [
            Repeater(
                callsign: "K4JPN-R",
                frequency: "146.970 MHz",
                offset: "-600 kHz",
                tone: "100.0 Hz",
                mode: "FM",
                location: CLLocationCoordinate2D(latitude: 35.5951, longitude: -79.3936),
                city: "Pittsboro",
                state: "NC",
                distanceMiles: nil,
                bearing: nil
            ),
            Repeater(
                callsign: "W4ROC-2",
                frequency: "145.230 MHz",
                offset: "-600 kHz",
                tone: "110.9 Hz",
                mode: "FM",
                location: CLLocationCoordinate2D(latitude: 35.7796, longitude: -78.6382),
                city: "Raleigh",
                state: "NC",
                distanceMiles: nil,
                bearing: nil
            ),
            Repeater(
                callsign: "W4UNC-1",
                frequency: "443.525 MHz",
                offset: "+5 MHz",
                tone: "100.0 Hz",
                mode: "D-Star",
                location: CLLocationCoordinate2D(latitude: 35.9132, longitude: -79.0558),
                city: "Chapel Hill",
                state: "NC",
                distanceMiles: nil,
                bearing: nil
            ),
        ]
    }

    // MARK: - Filtered / Sorted Results

    func filtered(userLocation: CLLocation?) -> [Repeater] {
        var result = repeaters

        // Apply text search
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.callsign.lowercased().contains(q) ||
                ($0.city?.lowercased().contains(q) ?? false) ||
                ($0.state?.lowercased().contains(q) ?? false) ||
                $0.frequency.contains(q)
            }
        }

        // Apply band filter
        if let band = selectedBand {
            result = result.filter { repeater in
                guard let freqStr = repeater.frequency.components(separatedBy: " ").first,
                      let freq = Double(freqStr) else { return false }
                return band.frequencyRangeMHz.contains(freq)
            }
        }

        // Calculate distance + bearing if location available
        if let loc = userLocation {
            result = result.map { r in
                var mutable = r
                let dest = CLLocation(latitude: r.location.latitude, longitude: r.location.longitude)
                mutable.distanceMiles = loc.distance(from: dest) / 1609.34
                mutable.bearing = loc.bearing(to: dest)
                return mutable
            }
        }

        // Sort
        switch sortOrder {
        case .distance:
            result.sort { ($0.distanceMiles ?? .infinity) < ($1.distanceMiles ?? .infinity) }
        case .frequency:
            result.sort { ($0.frequency) < ($1.frequency) }
        case .callsign:
            result.sort { $0.callsign < $1.callsign }
        case .tone:
            result.sort { ($0.tone ?? "") < ($1.tone ?? "") }
        }

        return result
    }

    // MARK: - Download RepeaterBook data

    func downloadRepeaterBook() async throws {
        // RepeaterBook provides a downloadable CSV/JSON export
        // URL: https://www.repeaterbook.com/api/repeaters.php
        // For now, use the sample data above
        // Real implementation: download + parse + bundle in app
    }
}
