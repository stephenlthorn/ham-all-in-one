import Foundation

// MARK: - Callsign Service (FCC ULS — free, no API key)

actor CallsignService {
    static let shared = CallsignService()

    // Cache to avoid repeated lookups
    private var cache: [String: CallsignRecord] = [:]

    // MARK: - FCC ULS API (free, public)

    /// Lookup a US amateur radio callsign via the FCC Universal Licensing System API
    func lookup(callsign: String) async throws -> CallsignRecord {
        let upper = callsign.uppercased().trimmingCharacters(in: .whitespaces)

        // Check cache first
        if let cached = cache[upper], !isExpired(cached) {
            return cached
        }

        // FCC ULS API — public, no key required
        // Returns XML with callsign, name, class, address, coordinates, etc.
        let encodedCall = upper.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? upper
        let urlStr = "https://wireless2.fcc.gov/UlsApp/UlsSearch/searchBasicXML.jsp?callsign=\(encodedCall)"

        guard let url = URL(string: urlStr) else {
            throw CallsignError.invalidCallsign
        }

        var request = URLRequest(url: url)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CallsignError.networkError
        }

        let record = try parseFCCResponse(data: data, callsign: upper)
        cache[upper] = record
        return record
    }

    private func isExpired(_ record: CallsignRecord) -> Bool {
        // Cache valid for 7 days
        Date().timeIntervalSince(record.lastFetched) < 7 * 24 * 3600
    }

    private func parseFCCResponse(data: Data, callsign: String) throws -> CallsignRecord {
        // Parse FCC ULS XML response
        // The FCC API returns XML — parse key fields
        guard let xmlString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw CallsignError.parseError
        }

        var record = CallsignRecord(callsign: callsign, lastFetched: Date())

        // Simple XML parsing for key fields
        record.operatorName = extractXML(xmlString, tag: "fullName")
        record.licenseClass = extractXML(xmlString, tag: "operatorClass")
        record.city = extractXML(xmlString, tag: "city")
        record.state = extractXML(xmlString, tag: "state")
        record.grid = extractXML(xmlString, tag: "grid")
        record.country = extractXML(xmlString, tag: "country") ?? "United States"

        if let latStr = extractXML(xmlString, tag: "latitude"),
           let lat = Double(latStr),
           let lonStr = extractXML(xmlString, tag: "longitude"),
           let lon = Double(lonStr) {
            record.latitude = lat
            record.longitude = lon
        }

        return record
    }

    private func extractXML(_ xml: String, tag: String) -> String? {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"
        guard let start = xml.range(of: openTag),
              let end = xml.range(of: closeTag) else { return nil }
        return String(xml[start.upperBound..<end.lowerBound])
    }

    // MARK: - QRZ.com API (requires subscription)

    /// QRZ.com lookup — requires active QRZ.com subscription
    /// Returns full callsign data including photo, bio, etc.
    func lookupQRZ(callsign: String, sessionKey: String) async throws -> CallsignRecord {
        // QRZ.com API requires session key from their auth
        // Endpoint: https://xmldata.qrz.com/xml/current/?s=<session_key>&callsign=<callsign>
        // This is a paid API (~USD 30/year)
        // For now, fall back to FCC ULS
        try await lookup(callsign: callsign)
    }
}

enum CallsignError: LocalizedError {
    case invalidCallsign
    case notFound
    case networkError
    case parseError
    case qrzSubscriptionRequired

    var errorDescription: String? {
        switch self {
        case .invalidCallsign: return "Invalid callsign format"
        case .notFound: return "Callsign not found in FCC database"
        case .networkError: return "Network error — check your connection"
        case .parseError: return "Failed to parse FCC response"
        case .qrzSubscriptionRequired: return "QRZ.com subscription required for full data"
        }
    }
}
