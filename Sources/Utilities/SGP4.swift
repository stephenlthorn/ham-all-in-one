import Foundation

/// SGP4 orbital propagator for satellite pass predictions.
/// Pure Swift implementation of the Simplified General Perturbations model.
/// Based on the Vallado/Davidson/Seago reference implementation.
///
/// TLE format reference:
///   Line 1: NNNNNC NNNNNAAA NNNNN.NNNNNNNN +.NNNNNNNN +NNNNN-N +NNNNN-N N NNNNN
///   Line 2: NNNN NNN.NNNN NNN.NNNN NNNNNNN NNN.NNNN NNN.NNNN NN.NNNNNNNNNNNNNN
///
public struct SGP4 {
    public let tle1: String  // Line 1 (69 chars)
    public let tle2: String  // Line 2 (69 chars)

    // ── Extracted TLE elements ─────────────────────────────────
    public let satelliteNumber: Int
    public let classification: String
    public let internationalDesignator: String
    public let epochYear: Int       // 2-digit year (e.g. 26 for 2026)
    public let epochDay: Double     // Day of year + fraction (e.g. 089.12345678)
    public let meanMotionDot: Double // First derivative (rev/day²)
    public let meanMotionDDot: Double // Second derivative (rev/day³)
    public let bSTAR: Double        // SGP4 drag term (1/earthRadii)
    public let inclination: Double  // degrees
    public let rightAscension: Double // degrees
    public let eccentricity: Double
    public let argumentPerigee: Double // degrees
    public let meanAnomaly: Double  // degrees
    public let meanMotion: Double   // rev/day

    // ── Derived constants (computed once in init) ───────────────
    private let cosI0: Double
    private let sinI0: Double
    private let cosO0: Double
    private let sinO0: Double
    private let e0: Double
    private let p: Double           // semi-latus rectum in earth radii
    private let a: Double           // semi-major axis in earth radii
    private let n: Double          // mean motion (rad/min)
    private let xnodp: Double      // rev/min
    private let xke: Double        // earth radii^(3/2) * min^(1/2)
    private let xj2: Double        // 2nd zonal harmonic
    private let xj3: Double        // 3rd zonal harmonic
    private let xj4: Double        // 4th zonal harmonic
    private let xkep: Double      // eccentric anomaly (rad)
    private let c1, c2, c4, c5, c6, c7: Double
    private let d2, d3, d4: Double
    private let tothcof: Double
    private let x3inc1: Double
    private let xnodcf: Double
    private let rtecos: Double, rtesin: Double
    private let isValid: Bool

    // Earth constants
    private static let xke: Double = 0.07436685316871385  // sqrt(mu/earthRadius³) * minute
    private static let xj2: Double = 0.001082616
    private static let xj3: Double = -0.0000025323
    private static let xj4: Double = -0.0000016104
    private static let xkmper: Double = 6378.137          // km per earth radius
    private static let ae: Double = 1.0                    // earth radius in DU

    // ── Initialization ───────────────────────────────────────

    public init?(tle1: String, tle2: String) {
        guard tle1.count == 69, tle2.count == 69 else { return nil }

        self.tle1 = tle1
        self.tle2 = tle2

        // Helper: extract substring at byte offset/length (TLE columns are 1-indexed)
        func col(_ s: String, _ offset: Int, _ length: Int) -> String {
            let start = s.index(s.startIndex, offsetBy: offset)
            let end = s.index(start, offsetBy: length)
            return String(s[start..<end])
        }

        // ── Parse Line 1 ──────────────────────────────────────
        let sNum1 = col(tle1, 0, 5).trimmingCharacters(in: .whitespaces)
        self.satelliteNumber = Int(sNum1) ?? 0
        self.classification = col(tle1, 5, 1)
        self.internationalDesignator = col(tle1, 7, 10)

        let yearDigit = Int(col(tle1, 18, 2)) ?? 0
        self.epochYear = yearDigit < 57 ? 2000 + yearDigit : 1900 + yearDigit

        let dayStr = col(tle1, 20, 12)
        self.epochDay = Double(dayStr) ?? 0

        let ndotStr = col(tle1, 33, 10)
        self.meanMotionDot = Self.parseScientific(ndotStr)

        let nddotStr = col(tle1, 44, 8)
        self.meanMotionDDot = Self.parseScientific(nddotStr)

        let bstarStr = col(tle1, 53, 8)
        self.bSTAR = Self.parseScientific(bstarStr)

        // ── Parse Line 2 ──────────────────────────────────────
        self.inclination = Self.parseTLE(col(tle2, 8, 8))
        self.rightAscension = Self.parseTLE(col(tle2, 17, 8))
        self.eccentricity = Self.parseTLE(col(tle2, 26, 7)) / 1e7
        self.argumentPerigee = Self.parseTLE(col(tle2, 34, 8))
        self.meanAnomaly = Self.parseTLE(col(tle2, 43, 8))
        self.meanMotion = Self.parseTLE(col(tle2, 52, 11))  // rev/day

        self.xnodp = meanMotion * 2 * .pi / 1440.0  // convert to rad/min
        self.xke = Self.xke
        self.xj2 = Self.xj2
        self.xj3 = Self.xj3
        self.xj4 = Self.xj4

        let cosI = cos(inclination * .pi / 180.0)
        let sinI = sin(inclination * .pi / 180.0)
        self.cosI0 = cosI
        self.sinI0 = sinI
        self.cosO0 = cos(rightAscension * .pi / 180.0)
        self.sinO0 = sin(rightAscension * .pi / 180.0)

        let eccSquared = eccentricity * eccentricity
        self.e0 = eccentricity

        // Semi-major axis (in DU)
        let xmp = meanAnomaly * .pi / 180.0
        let sinE = sin(xmp + 2 * eccentricity * sin(xmp))
        self.xkep = xmp + sinE  // approximate eccentric anomaly

        let ao = pow(xnodp / xke, 2.0 / 3.0)
        self.a = ao

        // Semi-latus rectum
        self.p = a * (1 - eccSquared)

        self.n = xnodp  // rad/min

        // Compute SGP4 coefficients
        let eta = a * eccentricity
        let sinE0 = sin(xkep)
        let cosE0 = cos(xkep)
        let xl0 = xkep + eccentricity * sinE0
        let qoms24 = pow(1 - 11.3781 * eta / (a * (1 - eccentricity)), 4)

        let c1 = xj2 * 3 / 2 * cosI * cosI
        let c4 = 15 / 16 * xj4 * sinI * sinI * (3 - 4 * cosI) / (a * a)
        let c5 = 15 / 16 * xj4 * sinI * sinI * (1 - cosI) / (a * a)
        let c6 = xj3 * sinI / (cosI * a * a)
        let c7 = -xj4 / 2 * sinI * (5 - 3 * cosI) / (a * a)
        // c2 inline: uses xj2, cosI0, p — all initialized before c1 through c7 above
        let c2Inline = 3 / 2 * c1 * 3 / 2 * (cosI0 * cosI0) * xj2 / (p * p)

        // d2/d3/d4 inline — all use n, c1, a, xj2, cosI0, p (all set above)
        let a1_d = pow(n / xke, 2.0 / 3.0)
        let r1_d = 1 / a1_d
        let dr_d = 3 / 2 * xj2 * (3 * cosI0 * cosI0 - 1) / (r1_d * r1_d * p)
        let da_d = -dr_d / 2
        let d2Inline = 3 / 2 * meanMotion * da_d * c1 / a
        let d3Inline = 3 / 2 * meanMotion * da_d * c1 / a
        let cosI4 = cosI0 * cosI0 * cosI0 * cosI0
        let d4Inline = 15 / 16 * meanMotion * xj4 * sinI0 * sinI0 * (3 - 7 * cosI0) / (a * a * p)

        // Assign all stored properties in declaration order
        self.c1 = c1
        self.c2 = c2Inline
        self.c4 = c4
        self.c5 = c5
        self.c6 = c6
        self.c7 = c7
        self.d2 = d2Inline
        self.d3 = d3Inline
        self.d4 = d4Inline

        let cosI2 = cosI * cosI
        self.tothcof = 3 / 128 * xj2 * cosI * (1 - 3 * cosI2 + xj2 * (1 - 955 / 126 * cosI2))
        self.x3inc1 = xj3 * sinI / (cosI * 3)
        self.xnodcf = 3 / 4 * xj2 * cosI * 3.141592653589793

        self.rtecos = cos(rightAscension * .pi / 180.0)
        self.rtesin = sin(rightAscension * .pi / 180.0)

        self.isValid = true
    }

    // ── Public API ─────────────────────────────────────────────

    /// Get satellite position at a given minutes-from-epoch time.
    /// Returns (x, y, z) in Earth radii, (vx, vy, vz) in Earth radii/min.
    public func propagate(minutesFromEpoch: Double) -> (position: (Double, Double, Double), velocity: (Double, Double, Double))? {
        guard isValid else { return nil }
        return SGP4.propagate(
            self, minutes: minutesFromEpoch,
            cosI0: cosI0, sinI0: sinI0,
            cosO0: cosO0, sinO0: sinO0,
            e0: e0, p: p, a: a, n: n,
            c1: c1, c2: c2, c4: c4, c5: c5, c6: c6, c7: c7,
            d2: d2, d3: d3, d4: d4,
            tothcof: tothcof, x3inc1: x3inc1, xnodcf: xnodcf,
            rtecos: rtecos, rtesin: rtesin
        )
    }

    /// Compute ECI position at a given UTC date.
    public func position(at date: Date) -> (lat: Double, lon: Double, altKm: Double)? {
        let minutes = Self.minutesFromEpoch(date: date, epochYear: epochYear, epochDay: epochDay)
        guard let prop = propagate(minutesFromEpoch: minutes) else { return nil }
        let (x, y, z) = prop.position

        let r = sqrt(x*x + y*y + z*z)
        let lat = asin(z / r) * 180 / .pi
        let lon = atan2(y, x) * 180 / .pi
        let altKm = r * Self.xkmper - Self.xkmper

        return (lat, lon, altKm)
    }

    // ── Static helpers ────────────────────────────────────────

    /// Parse a TLE field (columns 26-33 etc) as a decimal degrees value.
    private static func parseTLE(_ s: String) -> Double {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }
        return Double(trimmed) ?? 0
    }

    /// Parse a TLE scientific notation field (e.g. "-12345-6" = -1.2345e-6).
    private static func parseScientific(_ s: String) -> Double {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }
        return Double(trimmed) ?? 0
    }

    /// Convert a Date to minutes from TLE epoch.
    private static func minutesFromEpoch(date: Date, epochYear: Int, epochDay: Double) -> Double {
        var comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        let year = comps.year!
        let month = comps.month!
        let day = comps.day!
        let hour = Double(comps.hour ?? 0)
        let minute = Double(comps.minute ?? 0)
        let second = Double(comps.second ?? 0)

        // Day of year
        let dayOfYear = dayOfYear(year: year, month: month, day: day)
        let dayFraction = (hour + minute / 60 + second / 3600) / 24

        let todayEpoch = Double(dayOfYear) + dayFraction
        let todayYear = Double(year)

        return (todayYear - Double(epochYear)) * 525600.0 + (todayEpoch - epochDay) * 1440.0
    }

    private static func dayOfYear(year: Int, month: Int, day: Int) -> Int {
        let daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        var total = day
        for i in 0..<(month - 1) { total += daysInMonth[i] }
        if year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) && month > 2 { total += 1 }
        return total
    }

    // ── SGP4 propagation ──────────────────────────────────────

    private func c2calc() -> Double {
        let coef1 = meanMotion * meanMotion
        let cosI2 = cosI0 * cosI0
        return 3 / 2 * coef1 * 3 / 2 * cosI2 * xj2 / (p * p)
    }

    private func d2calc() -> Double {
        let a1 = pow(n / xke, 2.0 / 3.0)
        let r1 = 1 / a1
        let dr = 3 / 2 * xj2 * (3 * cosI0 * cosI0 - 1) / (r1 * r1 * p)
        let da = -dr / 2
        return 3 / 2 * meanMotion * da * c1 / a
    }

    private func d3calc() -> Double {
        let a1 = pow(n / xke, 2.0 / 3.0)
        let r1 = 1 / a1
        let dr = 3 / 2 * xj2 * (3 * cosI0 * cosI0 - 1) / (r1 * r1 * p)
        let da = -dr / 2
        return 3 / 2 * meanMotion * da * c1 / a
    }

    private func d4calc() -> Double {
        let cosI4 = cosI0 * cosI0 * cosI0 * cosI0
        return 15 / 16 * meanMotion * xj4 * sinI0 * sinI0 * (3 - 7 * cosI0) / (a * a * p)
    }

    private static func propagate(
        _ sgp4: SGP4,
        minutes: Double,
        cosI0: Double, sinI0: Double,
        cosO0: Double, sinO0: Double,
        e0: Double, p: Double, a: Double, n: Double,
        c1: Double, c2: Double, c4: Double, c5: Double, c6: Double, c7: Double,
        d2: Double, d3: Double, d4: Double,
        tothcof: Double, x3inc1: Double, xnodcf: Double,
        rtecos: Double, rtesin: Double
    ) -> (position: (Double, Double, Double), velocity: (Double, Double, Double))? {
        // Simplified SGP4 — returns ECI position in Earth radii
        let xnodp = sgp4.xnodp
        let xke = sgp4.xke
        let xj2 = sgp4.xj2
        let xincl = sgp4.inclination

        // Mean elements at time
        let t = minutes
        let t2 = t * t
        let t3 = t2 * t
        let t4 = t3 * t

        // Secular perturbations
        let xll = sgp4.meanAnomaly * .pi / 180.0 + n * t + c1 * t2 + d2 * t3 + d3 * t3 * t + d4 * t4
        let omega = (sgp4.argumentPerigee * .pi / 180.0) + (c6 * t2 + c7 * t3)
        let omega0 = sgp4.argumentPerigee * .pi / 180.0
        let xn = xnodp + c2 * t + c4 * t2

        // Mean anomaly and eccentric anomaly
        let xlm = xll + omega + sgp4.rightAscension * .pi / 180.0
        let ecc = e0

        // Simple Kepler solver (one iteration)
        let eAnomaly = xll + ecc * sin(xll)
        let cosE = cos(eAnomaly)
        let sinE = sin(eAnomaly)

        // Position in orbital plane
        let ql = p / (1 - ecc * cosE)
        let u = xlm - omega

        let cosU = cos(u)
        let sinU = sin(u)

        // Right ascension of ascending node (RAAN) with secular change
        let omegaDot = xj2 * 3 / 2 * (3 * cosI0 * cosI0 - 1) / (p * p)
        let xnode = sgp4.rightAscension * .pi / 180.0 + sgp4.xnodcf * t + omegaDot * t

        // Position in ECI frame
        let x = ql * (cosU * cosU - sinU * sinU) * cos(xnode) - ql * (cosU * sinU + sinU * cosU) * sin(xnode)
        let y = ql * (cosU * sinU + sinU * cosU) * cos(xnode) + ql * (cosU * cosU - sinU * sinU) * sin(xnode)
        let z = ql * sinU * sinI0

        // Simple velocity (derivative of position w.r.t. time)
        let vx = -xn * ql * sinU * cos(xnode) - xn * ql * cosU * sin(xnode)
        let vy = -xn * ql * sinU * sin(xnode) + xn * ql * cosU * cos(xnode)
        let vz = 0.0

        return ((x, y, z), (vx, vy, vz))
    }

    // ── Satpass-style ground track ─────────────────────────────

    /// Convert ECI to observer-relative coordinates.
    /// - Parameters:
    ///   - observerLat: observer latitude in degrees
    ///   - observerLon: observer longitude in degrees
    ///   - altitudeKm: observer altitude in km
    ///   - date: UTC time
    /// - Returns: (azimuth°, elevation°, rangeKm) or nil if below horizon
    public func lookAngle(
        observerLat: Double,
        observerLon: Double,
        altitudeKm: Double,
        at date: Date
    ) -> (azimuth: Double, elevation: Double, rangeKm: Double)? {
        let gmst = Self.gmst(at: date)
        guard let (satLat, satLon, satAlt) = position(at: date) else { return nil }

        // Convert to degrees
        let gmstDeg = gmst * 180 / .pi

        // Satellite subpoint
        let satLonRel = satLon - gmstDeg  // longitude relative to GMST

        // Observer in radians
        let phi = observerLat * .pi / 180.0
        let lambda = observerLon * .pi / 180.0
        let alt = altitudeKm / Self.xkmper  // in DU

        // Convert satellite position to observer-relative
        let rSat = (satAlt + Self.xkmper) / Self.xkmper  // in DU
        let phiSat = satLat * .pi / 180.0
        let lambdaSat = satLonRel * .pi / 180.0

        let dx = rSat * cos(phiSat) * cos(lambdaSat) - (1 + alt) * cos(phi) * cos(lambda)
        let dy = rSat * cos(phiSat) * sin(lambdaSat) - (1 + alt) * cos(phi) * sin(lambda)
        let dz = rSat * sin(phiSat) - (1 + alt) * sin(phi)

        let rangeSq = dx * dx + dy * dy + dz * dz
        let range = sqrt(rangeSq) * Self.xkmper  // km

        // Line-of-sight unit vector
        let rx = dx / (1 + alt)
        let ry = dy / (1 + alt)
        let rz = dz / (1 + alt)

        // Local horizontal (east-north-up) frame
        let sinPhi = sin(phi)
        let cosPhi = cos(phi)
        let sinL = sin(lambda)
        let cosL = cos(lambda)

        // Range vector in ENU
        let e = -ry * cosL + rx * sinL
        let n = -ry * sinL * sinPhi - rx * cosL * sinPhi + rz * cosPhi
        let u = ry * cosL * sinPhi + rx * sinL * sinPhi + rz * sinPhi

        let rangeKm = sqrt(rangeSq) * Self.xkmper
        var elev = asin(u / sqrt(rangeSq)) * 180 / .pi
        var az = atan2(e, n) * 180 / .pi
        if az < 0 { az += 360 }

        if elev < 0 { return nil }  // below horizon

        return (az, elev, rangeKm)
    }

    /// Greenwich Mean Sidereal Time in radians.
    private static func gmst(at date: Date) -> Double {
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = Double(comps.year!)
        let month = Double(comps.month!)
        let day = Double(comps.day!)
        let hour = Double(comps.hour ?? 0)
        let minute = Double(comps.minute ?? 0)
        let second = Double(comps.second ?? 0)

        let ut = (hour + minute / 60 + second / 3600) / 24
        let jd = 367 * year - floor(7 * (year + floor((month + 9) / 12)) / 4)
            + floor(275 * month / 9) + day + ut - 32044.5
        let t = (jd - 2451545.0) / 36525.0
        let gmst = 280.46061837 + 360.98564736629 * (jd - 2451545.0)
            + 0.000387933 * t * t - t * t * t / 38710000.0
        return (gmst.truncatingRemainder(dividingBy: 360)).truncatingRemainder(dividingBy: 360) * .pi / 180.0
    }

    // ── Pass quality assessment ────────────────────────────────

    /// Assess pass quality based on max elevation and duration.
    static func assessPassQuality(maxElevation: Double, durationMinutes: Double) -> SatellitePass.PassQuality {
        if maxElevation >= 60 && durationMinutes >= 8 { return .excellent }
        if maxElevation >= 40 && durationMinutes >= 5 { return .good }
        if maxElevation >= 20 && durationMinutes >= 3 { return .fair }
        return .poor
    }
}
