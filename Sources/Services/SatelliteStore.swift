import Foundation
import CoreLocation
import Combine

// MARK: - Satellite Store

@MainActor
final class SatelliteStore: ObservableObject {
    @Published private(set) var satellites: [Satellite] = []
    @Published private(set) var upcomingPasses: [SatellitePass] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isTLALoaded = false
    @Published private(set) var selectedSatellite: Satellite?

    // SGP4 propagators keyed by satellite name
    private var propagators: [String: SGP4] = [:]

    // Known amateur satellites with frequencies and NORAD IDs
    static let knownSatellites: [Satellite] = [
        Satellite(name: "ISS",         noradCatId: 25544, uplinkMHz: 145.990, downlinkMHz: 437.800, mode: "FM",  isActive: true),
        Satellite(name: "SO-50",      noradCatId: 27607, uplinkMHz: 145.850, downlinkMHz: 436.795, mode: "FM",  isActive: true),
        Satellite(name: "AO-91",      noradCatId: 43017, uplinkMHz: 435.250, downlinkMHz: 145.960, mode: "FM", isActive: true),
        Satellite(name: "AO-92",      noradCatId: 43137, uplinkMHz: 435.350, downlinkMHz: 145.880, mode: "FM", isActive: true),
        Satellite(name: "RS-44",      noradCatId: 44932, uplinkMHz: 435.640, downlinkMHz: 145.935, mode: "SSB/CW", isActive: true),
        Satellite(name: "XW-2A",      noradCatId: 40903, uplinkMHz: nil,       downlinkMHz: 435.030, mode: "SSB/CW", isActive: true),
        Satellite(name: "XW-2B",      noradCatId: 40967, uplinkMHz: nil,       downlinkMHz: 435.090, mode: "SSB/CW", isActive: true),
        Satellite(name: "FO-99",      noradCatId: 43937, uplinkMHz: 435.075, downlinkMHz: 145.405, mode: "FM", isActive: true),
    ]

    init() {
        satellites = Self.knownSatellites
    }

    // MARK: - TLE Loading

    /// Load TLE data from CelesTrak for all known satellites.
    func loadTLES() async {
        isLoading = true
        defer { Task { @MainActor in isLoading = false } }

        // CelesTrak provides a GP category URL for amateur satellites
        let urlStr = "https://www.celestrak.org/NORAD/elements/gp.php?GROUP=amateur&FORMAT=TLE"
        guard let url = URL(string: urlStr) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let content = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8) else { return }
            parseAndStoreTLES(content)
            isTLALoaded = true
        } catch {
            print("SatelliteStore: failed to load TLEs — \(error)")
        }
    }

    private func parseAndStoreTLES(_ content: String) {
        let lines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        var i = 0
        while i < lines.count - 1 {
            let nameLine = lines[i].trimmingCharacters(in: .whitespaces)
            let line1 = lines[i + 1]
            let line2 = lines[i + 2]

            // Validate format
            guard line1.count == 69, line2.count == 69 else {
                i += 1
                continue
            }

            // Match to known satellites by name
            if let sat = satellites.first(where: { nameLine.contains($0.name) }) {
                if let sgp4 = SGP4(tle1: line1, tle2: line2) {
                    propagators[sat.name] = sgp4
                    if let idx = satellites.firstIndex(where: { $0.id == sat.id }) {
                        satellites[idx].tleLine1 = line1
                        satellites[idx].tleLine2 = line2
                    }
                }
            }

            i += 3
        }
    }

    // MARK: - Pass Prediction

    /// Predict satellite passes for the next N hours.
    func calculatePasses(from location: CLLocation, within hours: Int = 24) {
        var allPasses: [SatellitePass] = []
        let start = Date()
        let stepSeconds = 60  // 1-minute grid for pass start search

        for sat in satellites where sat.isActive {
            guard let sgp4 = propagators[sat.name] else { continue }
            let passes = predictPasses(
                sgp4: sgp4,
                satelliteName: sat.name,
                observerLat: location.coordinate.latitude,
                observerLon: location.coordinate.longitude,
                observerAltKm: 0,
                startDate: start,
                hours: hours,
                stepSeconds: stepSeconds
            )
            allPasses.append(contentsOf: passes)
        }

        upcomingPasses = allPasses
            .sorted { $0.aosTime < $1.aosTime }
            .filter { $0.aosTime > Date() }
    }

    /// Predict passes for a single satellite.
    func calculatePasses(for satellite: Satellite, from location: CLLocation, within hours: Int = 24) -> [SatellitePass] {
        guard let sgp4 = propagators[satellite.name] else { return [] }
        return predictPasses(
            sgp4: sgp4,
            satelliteName: satellite.name,
            observerLat: location.coordinate.latitude,
            observerLon: location.coordinate.longitude,
            observerAltKm: 0,
            startDate: Date(),
            hours: hours,
            stepSeconds: 30
        )
    }

    /// Grid-scan for AOS/LOS events.
    private func predictPasses(
        sgp4: SGP4,
        satelliteName: String,
        observerLat: Double,
        observerLon: Double,
        observerAltKm: Double,
        startDate: Date,
        hours: Int,
        stepSeconds: Int
    ) -> [SatellitePass] {
        var passes: [SatellitePass] = []
        let endDate = startDate.addingTimeInterval(TimeInterval(hours * 3600))

        var scanDate = startDate
        var inPass = false
        var passStart: Date?
        var bestElevation: Double = 0
        var bestElevationTime: Date?

        while scanDate < endDate {
            if let angles = sgp4.lookAngle(
                observerLat: observerLat,
                observerLon: observerLon,
                altitudeKm: observerAltKm,
                at: scanDate
            ) {
                if !inPass {
                    // AOS — start of pass
                    inPass = true
                    passStart = scanDate
                    bestElevation = angles.elevation
                    bestElevationTime = scanDate
                } else {
                    if angles.elevation > bestElevation {
                        bestElevation = angles.elevation
                        bestElevationTime = scanDate
                    }
                }
            } else {
                if inPass {
                    // LOS — end of pass
                    inPass = false
                    let duration = scanDate.timeIntervalSince(passStart!)
                    let maxElev = bestElevation
                    let durationMinutes = duration / 60

                    if durationMinutes >= 1 {
                        if let aos = passStart,
                           let maxTime = bestElevationTime,
                           let aosAngles = sgp4.lookAngle(observerLat: observerLat, observerLon: observerLon, altitudeKm: observerAltKm, at: aos),
                           let losAngles = sgp4.lookAngle(observerLat: observerLat, observerLon: observerLon, altitudeKm: observerAltKm, at: scanDate) {
                            passes.append(SatellitePass(
                                satelliteName: satelliteName,
                                aosTime: aos,
                                losTime: scanDate,
                                maxElevation: maxElev,
                                aosAzimuth: aosAngles.azimuth,
                                losAzimuth: losAngles.azimuth,
                                quality: SatellitePass.assessPassQuality(maxElevation: maxElev, durationMinutes: durationMinutes)
                            ))
                        }
                    }

                    passStart = nil
                    bestElevation = 0
                    bestElevationTime = nil
                }
            }

            scanDate = scanDate.addingTimeInterval(TimeInterval(stepSeconds))
        }

        return passes
    }

    // MARK: - Live Position

    /// Current look angle to a satellite from observer location.
    func lookAngle(to satellite: Satellite, from location: CLLocation) -> (azimuth: Double, elevation: Double, rangeKm: Double)? {
        guard let sgp4 = propagators[satellite.name] else { return nil }
        return sgp4.lookAngle(
            observerLat: location.coordinate.latitude,
            observerLon: location.coordinate.longitude,
            altitudeKm: 0,
            at: Date()
        )
    }

    // MARK: - QSO Helpers

    func logSatelliteQSO(
        satellite: Satellite,
        pass: SatellitePass,
        myCallsign: String
    ) -> QSO {
        QSO(
            callsign: "",
            datetime: Date(),
            satelliteName: satellite.name,
            operatorCallsign: myCallsign
        )
    }
}

// MARK: - Pass Quality

extension SatellitePass {
    static func assessPassQuality(maxElevation: Double, durationMinutes: Double) -> SatellitePass.PassQuality {
        if maxElevation >= 60 && durationMinutes >= 8 { return .excellent }
        if maxElevation >= 40 && durationMinutes >= 5 { return .good }
        if maxElevation >= 20 && durationMinutes >= 3 { return .fair }
        return .poor
    }
}
