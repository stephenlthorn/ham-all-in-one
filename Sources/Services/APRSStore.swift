import Foundation

/// APRS station lookup via APRS.fi public hamlib endpoint.
/// Tracks and displays amateur station positions on a map.
///
@MainActor
final class APRSStore: ObservableObject {
    /// A station's APRS position report.
    struct APRSStation: Identifiable, Codable {
        let id: UUID
        let callsign: String
        let latitude: Double
        let longitude: Double
        let altitudeM: Double?
        let course: Int?
        let speedKmh: Int?
        let symbol: String?       // APRS symbol code
        let lastSeen: Date
        let comment: String?
        let source: String        // e.g. "APRS", "AIS"

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    @Published private(set) var stations: [String: APRSStation] = [:]  // keyed by callsign
    @Published private(set) var myStation: APRSStation?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // APRS.fi public hamlib endpoint (no API key needed for ham apps)
    private static let baseURL = "https://aprs.fi/hamlib/"

    // ── Lookup ─────────────────────────────────────────────

    /// Look up a single callsign's APRS position.
    func lookup(callsign: String) async {
        let trimmed = callsign.uppercased().trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let station = try await fetchStation(callsign: trimmed)
            stations[trimmed] = station
            if trimmed == UserDefaults.standard.string(forKey: "ham.myCallsign")?.uppercased() {
                myStation = station
            }
        } catch {
            errorMessage = "APRS not found for \(trimmed)"
        }

        isLoading = false
    }

    /// Batch lookup multiple callsigns.
    func lookupBatch(_ callsigns: [String]) async {
        for call in callsigns {
            await lookup(callsign: call)
        }
    }

    private func fetchStation(callsign: String) async throws -> APRSStation {
        let urlStr = "\(Self.baseURL)?name=\(callsign)&what=loc&format=json"
        guard let url = URL(string: urlStr) else {
            throw APRSError.invalidCallsign
        }

        var request = URLRequest(url: url)
        request.setValue("HAMAllInOne/1.0 (ham app)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APRSError.networkError
        }

        if httpResponse.statusCode == 404 || data.count < 10 {
            throw APRSError.notFound
        }

        let entries = try JSONDecoder().decode([APRSFIResponse].self, from: data)

        guard let first = entries.first else {
            throw APRSError.notFound
        }

        return APRSStation(
            id: UUID(),
            callsign: first.name.uppercased(),
            latitude: first.lat,
            longitude: first.lng,
            altitudeM: first.altitude,
            course: first.course,
            speedKmh: first.speed,
            symbol: first.symbol,
            lastSeen: Date(timeIntervalSince1970: TimeInterval(first.lasttime)),
            comment: first.comment,
            source: first.type
        )
    }

    // ── Search ─────────────────────────────────────────────

    /// Search for stations near a location.
    func searchNearby(lat: Double, lon: Double, radiusKm: Double = 50) async {
        isLoading = true
        errorMessage = nil

        let urlStr = "\(Self.baseURL)?what=loc&lat=\(lat)&lon=\(lon)&range=\(radiusKm)&format=json"
        guard let url = URL(string: urlStr) else {
            isLoading = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("HAMAllInOne/1.0", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await URLSession.shared.data(for: request)
            let entries = try JSONDecoder().decode([APRSFIResponse].self, from: data)

            for entry in entries {
                let station = APRSStation(
                    id: UUID(),
                    callsign: entry.name.uppercased(),
                    latitude: entry.lat,
                    longitude: entry.lng,
                    altitudeM: entry.altitude,
                    course: entry.course,
                    speedKmh: entry.speed,
                    symbol: entry.symbol,
                    lastSeen: Date(timeIntervalSince1970: TimeInterval(entry.lasttime)),
                    comment: entry.comment,
                    source: entry.type
                )
                stations[station.callsign] = station
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // ── Clear ─────────────────────────────────────────────

    func clear() {
        stations.removeAll()
        myStation = nil
    }
}

// MARK: - APRS.fi JSON response

private struct APRSFIResponse: Codable {
    let name: String
    let type: String
    let lat: Double
    let lng: Double
    let altitude: Double?
    let course: Int?
    let speed: Int?
    let symbol: String?
    let comment: String?
    let lasttime: Int
}

// MARK: - Errors

enum APRSError: LocalizedError {
    case invalidCallsign
    case notFound
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidCallsign: return "Invalid callsign"
        case .notFound:        return "Station not found on APRS"
        case .networkError:    return "Network error"
        }
    }
}

import CoreLocation
