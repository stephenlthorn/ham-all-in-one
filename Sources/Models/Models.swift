import Foundation
import CoreLocation

// MARK: - QSO / Contact Log

struct QSO: Identifiable, Codable {
    let id: UUID
    var callsign: String
    var datetime: Date
    var frequency: String?       // e.g. "146.520 MHz"
    var mode: String?             // e.g. "FM", "SSB", "FT8"
    var rstSent: String?
    var rstReceived: String?
    var notes: String?
    var grid: String?            // Maidenhead locator
    var repeaterCallsign: String?
    var satelliteName: String?
    var contestExchange: String?
    var operatorCallsign: String // station operator's license

    init(
        id: UUID = UUID(),
        callsign: String,
        datetime: Date = Date(),
        frequency: String? = nil,
        mode: String? = nil,
        rstSent: String? = nil,
        rstReceived: String? = nil,
        notes: String? = nil,
        grid: String? = nil,
        repeaterCallsign: String? = nil,
        satelliteName: String? = nil,
        contestExchange: String? = nil,
        operatorCallsign: String
    ) {
        self.id = id
        self.callsign = callsign
        self.datetime = datetime
        self.frequency = frequency
        self.mode = mode
        self.rstSent = rstSent
        self.rstReceived = rstReceived
        self.notes = notes
        self.grid = grid
        self.repeaterCallsign = repeaterCallsign
        self.satelliteName = satelliteName
        self.contestExchange = contestExchange
        self.operatorCallsign = operatorCallsign
    }
}

// MARK: - Repeater

struct Repeater: Identifiable, Codable {
    let id: UUID
    var callsign: String
    var frequency: String         // e.g. "146.520 MHz"
    var offset: String?           // e.g. "+600 kHz"
    var tone: String?            // CTCSS/PL tone, e.g. "100.0 Hz"
    var mode: String?            // FM, D-Star, Fusion, etc.
    var location: CLLocationCoordinate2D
    var city: String?
    var state: String?
    var country: String?
    var distanceMiles: Double?    // calculated from user location
    var bearing: Double?         // degrees from user location
    var isOnline: Bool?
    var lastUpdated: Date?
    var url: String?

    init(
        id: UUID = UUID(),
        callsign: String,
        frequency: String,
        offset: String? = nil,
        tone: String? = nil,
        mode: String? = nil,
        location: CLLocationCoordinate2D,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
        distanceMiles: Double? = nil,
        bearing: Double? = nil,
        isOnline: Bool? = nil,
        lastUpdated: Date? = nil,
        url: String? = nil
    ) {
        self.id = id
        self.callsign = callsign
        self.frequency = frequency
        self.offset = offset
        self.tone = tone
        self.mode = mode
        self.location = location
        self.city = city
        self.state = state
        self.country = country
        self.distanceMiles = distanceMiles
        self.bearing = bearing
        self.isOnline = isOnline
        self.lastUpdated = lastUpdated
        self.url = url
    }
}

// Codable conformance for CLLocationCoordinate2D
extension CLLocationCoordinate2D: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let latitude = try container.decode(Double.self)
        let longitude = try container.decode(Double.self)
        self.init(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(latitude)
        try container.encode(longitude)
    }
}

// MARK: - Satellite

struct Satellite: Identifiable, Codable {
    let id: UUID
    var name: String             // e.g. "ISS", "SO-50"
    var noradCatId: Int?          // NORAD catalog ID
    var tleLine1: String?
    var tleLine2: String?
    var uplinkMHz: Double?
    var downlinkMHz: Double?
    var mode: String?             // e.g. "FM", "UV段"
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        noradCatId: Int? = nil,
        tleLine1: String? = nil,
        tleLine2: String? = nil,
        uplinkMHz: Double? = nil,
        downlinkMHz: Double? = nil,
        mode: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.noradCatId = noradCatId
        self.tleLine1 = tleLine1
        self.tleLine2 = tleLine2
        self.uplinkMHz = uplinkMHz
        self.downlinkMHz = downlinkMHz
        self.mode = mode
        self.isActive = isActive
    }
}

// MARK: - Satellite Pass

struct SatellitePass: Identifiable {
    let id: UUID
    var satelliteName: String
    var aosTime: Date      // Acquisition of Signal — pass start
    var losTime: Date      // Loss of Signal — pass end
    var maxElevation: Double // degrees above horizon
    var aosAzimuth: Double  // degrees
    var losAzimuth: Double
    var quality: PassQuality

    var duration: TimeInterval {
        losTime.timeIntervalSince(aosTime)
    }

    enum PassQuality: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"

        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "yellow"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }
    }

    init(
        id: UUID = UUID(),
        satelliteName: String,
        aosTime: Date,
        losTime: Date,
        maxElevation: Double,
        aosAzimuth: Double,
        losAzimuth: Double,
        quality: PassQuality
    ) {
        self.id = id
        self.satelliteName = satelliteName
        self.aosTime = aosTime
        self.losTime = losTime
        self.maxElevation = maxElevation
        self.aosAzimuth = aosAzimuth
        self.losAzimuth = losAzimuth
        self.quality = quality
    }
}

// MARK: - Callsign Lookup Result

struct CallsignRecord: Identifiable, Codable {
    let id: UUID
    var callsign: String
    var operatorName: String?
    var licenseClass: String?    // Technician, General, Extra
    var address: String?
    var city: String?
    var state: String?
    var zip: String?
    var country: String?
    var grid: String?             // Maidenhead grid
    var latitude: Double?
    var longitude: Double?
    var email: String?
    var photoURL: String?
    var bio: String?
    var qrZURL: String?
    var lastFetched: Date

    init(
        id: UUID = UUID(),
        callsign: String,
        operatorName: String? = nil,
        licenseClass: String? = nil,
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zip: String? = nil,
        country: String? = nil,
        grid: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        email: String? = nil,
        photoURL: String? = nil,
        bio: String? = nil,
        qrZURL: String? = nil,
        lastFetched: Date = Date()
    ) {
        self.id = id
        self.callsign = callsign
        self.operatorName = operatorName
        self.licenseClass = licenseClass
        self.address = address
        self.city = city
        self.state = state
        self.zip = zip
        self.country = country
        self.grid = grid
        self.latitude = latitude
        self.longitude = longitude
        self.email = email
        self.photoURL = photoURL
        self.bio = bio
        self.qrZURL = qrZURL
        self.lastFetched = lastFetched
    }
}

// MARK: - Maidenhead / Grid

struct Maidenhead {
    static func encode(lat: Double, lon: Double) -> String {
        let adjustedLon = lon + 180.0
        let adjustedLat = lat + 90.0

        func toChar(_ ascii: Int) -> Character {
            Character(UnicodeScalar(ascii)!)
        }

        let field1     = toChar(65 + Int(adjustedLon / 20))
        let field2     = toChar(65 + Int(adjustedLat / 10))
        let square1    = toChar(48 + Int((adjustedLon.truncatingRemainder(dividingBy: 20)) / 2))
        let square2    = toChar(48 + Int(adjustedLat.truncatingRemainder(dividingBy: 10)))
        let subsquare1 = toChar(97 + Int((adjustedLon.truncatingRemainder(dividingBy: 2)) * 12))
        let subsquare2 = toChar(97 + Int((adjustedLat.truncatingRemainder(dividingBy: 10)) * 12))

        return String([field1, field2, square1, square2, subsquare1, subsquare2])
    }

    static func decode(_ grid: String) -> (lat: Double, lon: Double)? {
        guard grid.count >= 4 else { return nil }
        let chars = Array(grid.uppercased())
        guard chars.count >= 4 else { return nil }

        let field1Lon = Double(chars[0].asciiValue! - 65) * 20 - 180
        let field2Lat = Double(chars[1].asciiValue! - 65) * 10 - 90
        let square1Lon = Double(chars[2].wholeNumberValue! / 2)
        let square2Lat = Double(chars[3].wholeNumberValue!)

        let lon = field1Lon + square1Lon
        let lat = field2Lat + square2Lat

        return (lat, lon)
    }

    /// Calculate bearing and distance between two Maidenhead grid squares
    static func bearingAndDistance(from: String, to: String) -> (bearing: Double, distanceMiles: Double)? {
        guard let fromLoc = decode(from), let toLoc = decode(to) else { return nil }

        let fromCoord = CLLocation(latitude: fromLoc.lat, longitude: fromLoc.lon)
        let toCoord = CLLocation(latitude: toLoc.lat, longitude: toLoc.lon)

        let distance = fromCoord.distance(from: toCoord) / 1609.34 // meters to miles
        let bearing = fromCoord.bearing(to: toCoord)

        return (bearing, distance)
    }
}

import CoreLocation

extension CLLocation {
    func bearing(to destination: CLLocation) -> Double {
        let lat1 = self.coordinate.latitude.degreesToRadians
        let lon1 = self.coordinate.longitude.degreesToRadians
        let lat2 = destination.coordinate.latitude.degreesToRadians
        let lon2 = destination.coordinate.longitude.degreesToRadians

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)

        return (radiansBearing.radiansToDegrees + 360).truncatingRemainder(dividingBy: 360)
    }
}

extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}

// MARK: - DXCC Entity

struct DXCCEntity: Identifiable, Codable {
    let id: UUID
    var prefix: String           // e.g. "K", "W", "VE"
    var country: String
    var cqZone: Int?
    var ituZone: Int?
    var continent: String?       // NA, SA, EU, AS, AF, OC

    init(id: UUID = UUID(), prefix: String, country: String, cqZone: Int? = nil, ituZone: Int? = nil, continent: String? = nil) {
        self.id = id
        self.prefix = prefix
        self.country = country
        self.cqZone = cqZone
        self.ituZone = ituZone
        self.continent = continent
    }
}

// MARK: - Repeater Band

enum RepeaterBand: String, CaseIterable {
    case band10m = "10m"
    case band6m = "6m"
    case band2m = "2m"
    case band70cm = "70cm"
    case band23cm = "23cm"

    var frequencyRangeMHz: ClosedRange<Double> {
        switch self {
        case .band10m: return 28.0...29.7
        case .band6m: return 50.0...54.0
        case .band2m: return 144.0...148.0
        case .band70cm: return 420.0...450.0
        case .band23cm: return 1240.0...1300.0
        }
    }
}

// MARK: - Ham Mode

enum HamMode: String, CaseIterable {
    case fm = "FM"
    case am = "AM"
    case ssb = "SSB"
    case cw = "CW"
    case ft8 = "FT8"
    case ft4 = "FT4"
    case digital = "Digital"
    case dstar = "D-Star"
    case fusion = "Fusion"
    case aprs = "APRS"
    case sstv = "SSTV"
    case satellite = "SAT"
}
