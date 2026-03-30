import Foundation
import CoreLocation
import Combine

// MARK: - Repeater Store

/// Loads US amateur radio repeater data from the ARD (Amateur Repeater Directory).
/// Data is fetched from the ham-radio-data GitHub repo on first launch,
/// then cached locally for offline use.
///
@MainActor
final class RepeaterStore: ObservableObject {
    @Published private(set) var repeaters: [Repeater] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String?
    @Published var searchQuery = ""
    @Published var selectedBand: RepeaterBand?
    @Published var sortOrder: SortOrder = .distance

    enum SortOrder {
        case distance, frequency, callsign, tone
    }

    /// Remote data URL — updated weekly via GitHub Action sync
    private static let remoteURL = URL(string: "https://raw.githubusercontent.com/stephenlthorn/ham-radio-data/main/MasterRepeater.json")!

    /// Local cache path in the app's documents directory
    private var localCacheURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("RepeaterCache.json")
    }

    // ── Init ─────────────────────────────────────────────────

    init() {
        Task { await loadRepeaters() }
    }

    // ── Load / Refresh ───────────────────────────────────────

    /// Main entry point: load from cache or network.
    func loadRepeaters() async {
        isLoading = true
        errorMessage = nil

        // 1. Try local cache first
        if let cached = loadFromCache() {
            repeaters = cached
            isLoading = false
            // 2. Refresh from network in background if stale (>24h)
            if let lastUpdated = lastUpdated,
               Date().timeIntervalSince(lastUpdated) > 24 * 3600 {
                Task { await refreshFromNetwork() }
            }
            return
        }

        // 3. No cache — fetch from network
        await refreshFromNetwork()
        isLoading = false
    }

    /// Force-refresh from the network.
    func refreshFromNetwork() async {
        isLoading = true
        errorMessage = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: Self.remoteURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw RepeaterStoreError.networkError
            }

            let remoteRepeaters = try parseARDRepeaters(from: data)
            repeaters = remoteRepeaters
            lastUpdated = Date()
            saveToCache(remoteRepeaters)

        } catch {
            errorMessage = "Failed to load repeaters: \(error.localizedDescription)"
            // Fall back to bundled sample data
            if repeaters.isEmpty {
                loadSampleData()
            }
        }

        isLoading = false
    }

    // ── Cache ─────────────────────────────────────────────────

    private func loadFromCache() -> [Repeater]? {
        guard FileManager.default.fileExists(atPath: localCacheURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: localCacheURL)
            let cached: CachedRepeaters = try JSONDecoder().decode(CachedRepeaters.self, from: data)
            lastUpdated = cached.cachedAt
            return cached.repeaters
        } catch {
            return nil
        }
    }

    private func saveToCache(_ repeaters: [Repeater]) {
        let cached = CachedRepeaters(repeaters: repeaters, cachedAt: Date())
        do {
            let data = try JSONEncoder().encode(cached)
            try data.write(to: localCacheURL, options: .atomic)
        } catch {
            print("RepeaterStore: failed to save cache — \(error)")
        }
    }

    // ── ARD JSON Parsing ──────────────────────────────────────

    /// Parse ARD master repeater JSON into our Repeater model.
    private func parseARDRepeaters(from data: Data) throws -> [Repeater] {
        let arddEntries = try JSONDecoder().decode([ARDRepeaterEntry].self, from: data)

        return arddEntries.compactMap { entry -> Repeater? in
            guard entry.isOperational && entry.isOpen else { return nil }
            guard entry.outputFrequency > 0 else { return nil }

            let freqMHz = String(format: "%.3f", entry.outputFrequency)

            var offsetStr: String?
            if let offset = entry.offset, offset > 0 {
                let sign = entry.offsetSign == "+" ? "+" : "-"
                offsetStr = "\(sign)\(String(format: "%.3f", offset)) MHz"
            }

            var toneStr: String?
            let rxTone = entry.ctcssRx ?? 0
            let txTone = entry.ctcssTx ?? 0
            if rxTone > 0 || txTone > 0 {
                let tone = entry.toneMode == "TSQL" ? txTone : rxTone
                if tone > 0 {
                    toneStr = String(format: "%.1f Hz", tone)
                }
            }

            let modeStr: String?
            switch entry.band {
            case "2m":   modeStr = entry.toneMode == "D-Star" ? "D-Star" : "FM"
            case "70cm": modeStr = entry.toneMode == "D-Star" ? "D-Star" : "FM"
            default:     modeStr = entry.toneMode ?? "FM"
            }

            return Repeater(
                id: UUID(),
                callsign: entry.callsign,
                frequency: "\(freqMHz) MHz",
                offset: offsetStr,
                tone: toneStr,
                mode: modeStr,
                location: CLLocationCoordinate2D(
                    latitude: entry.latitude,
                    longitude: entry.longitude
                ),
                city: entry.nearestCity,
                state: entry.state,
                country: "United States",
                distanceMiles: nil,
                bearing: nil,
                isOnline: entry.isOpen,
                lastUpdated: nil,
                url: nil
            )
        }
    }

    // ── Sample Data (fallback) ────────────────────────────────

    private func loadSampleData() {
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

        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.callsign.lowercased().contains(q) ||
                ($0.city?.lowercased().contains(q) ?? false) ||
                ($0.state?.lowercased().contains(q) ?? false) ||
                $0.frequency.contains(q)
            }
        }

        if let band = selectedBand {
            result = result.filter { repeater in
                guard let freqStr = repeater.frequency.components(separatedBy: " ").first,
                      let freq = Double(freqStr) else { return false }
                return band.frequencyRangeMHz.contains(freq)
            }
        }

        if let loc = userLocation {
            result = result.map { r in
                var mutable = r
                let dest = CLLocation(latitude: r.location.latitude, longitude: r.location.longitude)
                mutable.distanceMiles = loc.distance(from: dest) / 1609.34
                mutable.bearing = loc.bearing(to: dest)
                return mutable
            }
        }

        switch sortOrder {
        case .distance:
            result.sort { ($0.distanceMiles ?? .infinity) < ($1.distanceMiles ?? .infinity) }
        case .frequency:
            result.sort { $0.frequency < $1.frequency }
        case .callsign:
            result.sort { $0.callsign < $1.callsign }
        case .tone:
            result.sort { ($0.tone ?? "") < ($1.tone ?? "") }
        }

        return result
    }
}

// MARK: - ARD JSON Entry

/// Matches the JSON structure from the Amateur Repeater Directory (ARD).
private struct ARDRepeaterEntry: Codable {
    let repeaterId: String
    let outputFrequency: Double    // MHz, e.g. 442.750
    let inputFrequency: Double?    // MHz
    let offset: Double?           // MHz
    let offsetSign: String?       // "+" or "-"
    let band: String?              // "2m", "70cm", etc.
    let toneMode: String?          // "TSQL", "CTCSS", "DCS", "D-Star", etc.
    let ctcssTx: Double?          // Hz
    let ctcssRx: Double?          // Hz
    let callsign: String
    let latitude: Double
    let longitude: Double
    let state: String?
    let county: String?
    let nearestCity: String?
    let isOperational: Bool
    let isOpen: Bool
    let isCoordinated: Bool?
    let ares: Bool?
    let skywarn: Bool?
}

// MARK: - Cache Wrapper

private struct CachedRepeaters: Codable {
    let repeaters: [Repeater]
    let cachedAt: Date
}

// MARK: - Errors

enum RepeaterStoreError: LocalizedError {
    case networkError
    case parseError

    var errorDescription: String? {
        switch self {
        case .networkError: return "Network error — check your connection"
        case .parseError:  return "Failed to parse repeater data"
        }
    }
}
