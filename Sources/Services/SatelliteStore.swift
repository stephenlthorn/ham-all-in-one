import Foundation
import CoreLocation
import Combine

// MARK: - Satellite Store

@MainActor
final class SatelliteStore: ObservableObject {
    @Published private(set) var satellites: [Satellite] = []
    @Published private(set) var upcomingPasses: [SatellitePass] = []
    @Published private(set) var isLoading = false
    @Published private(set) var selectedSatellite: Satellite?

    // Known amateur radio satellites with frequencies
    static let knownSatellites: [Satellite] = [
        Satellite(name: "ISS", noradCatId: 25544, uplinkMHz: 145.990, downlinkMHz: 437.800, mode: "FM", isActive: true),
        Satellite(name: "SO-50", noradCatId: 27607, uplinkMHz: 145.850, downlinkMHz: 436.795, mode: "FM", isActive: true),
        Satellite(name: "AO-91", noradCatId: 43017, uplinkMHz: 435.250, downlinkMHz: 145.960, mode: "FM", isActive: true),
        Satellite(name: "AO-92", noradCatId: 43137, uplinkMHz: 435.350, downlinkMHz: 145.880, mode: "FM", isActive: true),
        Satellite(name: "CAS-4A (XW-2A)", noradCatId: 40903, uplinkMHz: nil, downlinkMHz: 435.030, mode: "SSB/CW", isActive: true),
        Satellite(name: "CAS-4B (XW-2B)", noradCatId: 40967, uplinkMHz: nil, downlinkMHz: 435.090, mode: "SSB/CW", isActive: true),
        Satellite(name: "FO-99", noradCatId: 43937, uplinkMHz: 435.075, downlinkMHz: 145.405, mode: "FM", isActive: true),
        Satellite(name: "RS-44", noradCatId: 44932, uplinkMHz: 435.640, downlinkMHz: 145.935, mode: "SSB/CW", isActive: true),
    ]

    init() {
        satellites = Self.knownSatellites
    }

    // MARK: - TLE Loading

    func loadTLES() async {
        isLoading = true
        defer { Task { @MainActor in isLoading = false } }

        do {
            // Load TLEs from CelesTrak (free, no auth required)
            let url = URL(string: "https://www.celestrak.org/NORAD/elements/gp.php?GROUP=amateur&FORMAT=TLE")!
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let content = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8) else { return }

            // Parse TLEs and update satellites
            let tles = parseTLE(content)
            for tle in tles {
                if let idx = satellites.firstIndex(where: { $0.name == tle.name }) {
                    satellites[idx].tleLine1 = tle.line1
                    satellites[idx].tleLine2 = tle.line2
                }
            }
        } catch {
            print("Failed to load TLE data: \(error)")
        }
    }

    struct TLEEntry {
        let name: String
        let line1: String
        let line2: String
    }

    private func parseTLE(_ content: String) -> [TLEEntry] {
        var results: [TLEEntry] = []
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        var i = 0
        while i < lines.count - 2 {
            let name = lines[i].trimmingCharacters(in: .whitespaces)
            let line1 = lines[i + 1]
            let line2 = lines[i + 2]
            if line1.count == 69 && line2.count == 69 {
                results.append(TLEEntry(name: name, line1: line1, line2: line2))
                i += 3
            } else {
                i += 1
            }
        }
        return results
    }

    // MARK: - Pass Prediction

    func predictPasses(for satellite: Satellite, from location: CLLocation, within hours: Int = 24) -> [SatellitePass] {
        guard let tle1 = satellite.tleLine1, let tle2 = satellite.tleLine2 else {
            return []
        }

        // SGP4 simplified pass prediction
        // For a production app, use a proper SGP4 library (e.g., port from NASA/Novas)
        // This is a simplified placeholder that generates mock passes
        // Real implementation needed here

        // Placeholder: generate a mock pass if TLEs are available
        var passes: [SatellitePass] = []
        let now = Date()

        for h in stride(from: 0, to: Double(hours), by: 1.5) {
            let aosTime = now.addingTimeInterval(h * 3600)
            let durationMinutes = Double.random(in: 5...15)
            let losTime = aosTime.addingTimeInterval(durationMinutes * 60)
            let maxElev = Double.random(in: 10...80)
            let quality: SatellitePass.PassQuality
            switch maxElev {
            case 60...: quality = .excellent
            case 40..<60: quality = .good
            case 20..<40: quality = .fair
            default: quality = .poor
            }

            passes.append(SatellitePass(
                satelliteName: satellite.name,
                aosTime: aosTime,
                losTime: losTime,
                maxElevation: maxElev,
                aosAzimuth: Double.random(in: 0...360),
                losAzimuth: Double.random(in: 0...360),
                quality: quality
            ))
        }

        return passes.sorted { $0.aosTime < $1.aosTime }
    }

    func calculatePasses(from location: CLLocation, within hours: Int = 24) {
        var allPasses: [SatellitePass] = []
        for sat in satellites where sat.isActive {
            let passes = predictPasses(for: sat, from: location, within: hours)
            allPasses.append(contentsOf: passes)
        }
        upcomingPasses = allPasses.sorted { $0.aosTime < $1.aosTime }
    }

    // MARK: - QSO Logging for Satellites

    func logSatelliteQSO(satellite: Satellite, pass: SatellitePass, operatorCallsign: String) -> QSO {
        QSO(
            callsign: "",
            datetime: Date(),
            satelliteName: satellite.name,
            operatorCallsign: operatorCallsign
        )
    }
}
