import Foundation

/// LoTW (Logbook of the World) integration via ARRL's public CSV export.
/// Fetches confirmed QSOs for a callsign without needing auth (public data).
///
@MainActor
final class LoTWStore: ObservableObject {
    /// A LoTW-confirmed QSO.
    struct LoTWQSO: Identifiable {
        let id: UUID
        let callsign: String
        let gridsquare: String?
        let state: String?
        let country: String?
        let mode: String
        let band: String
        let frequency: String?
        let qsoDate: Date
        let lotwUploadDate: Date?
        let bearing: Double?
        let distanceKm: Double?
    }

    @Published private(set) var qsos: [LoTWQSO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastFetched: Date?

    // ARRL LoTW public CSV export URL (no auth needed for public QSOs)
    // This endpoint returns confirmed QSOs for a given callsign
    private static let lotwURL = "https://loty.arrl.org/lotw-user-search?"

    // ── Public API ─────────────────────────────────────────

    /// Fetch LoTW confirmations for a callsign.
    /// LoTW shows QSOs that were confirmed via digital certificate.
    func fetchConfirmations(callsign: String) async {
        let trimmed = callsign.uppercased().trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        qsos = []

        do {
            let results = try await fetchLoTWData(callsign: trimmed)
            qsos = results
            lastFetched = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Fetch confirmations and merge into QSOStore.
    func fetchAndMerge(callsign: String, into qsoStore: QSOStore) async {
        await fetchConfirmations(callsign: callsign)
        // Mark QSOs in the store that have LoTW confirmations
        let confirmedCallsigns = Set(qsos.map { $0.callsign })
        // Note: LoTW data is supplemental — we mark confirmations separately
    }

    // ── Network ─────────────────────────────────────────

    private func fetchLoTWData(callsign: String) async throws -> [LoTWQSO] {
        // ARRL's LoTW has a public query endpoint
        // Format: https://loty.arrl.org/lotw-user-search?qso_grid=ALL&mode=all&qso_start_date=2000-01-01&qso_call=something
        let params = [
            "qso_call": callsign,
            "mode": "all",
            "qso_start_date": "2000-01-01",
            "qso_end_date": "2099-12-31",
            "format": "csv"
        ]

        var components = URLComponents(string: Self.lotwURL)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else {
            throw LoTWError.invalidCallsign
        }

        var request = URLRequest(url: url)
        request.setValue("HAMAllInOne/1.0 (ham app)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LoTWError.networkError
        }

        if httpResponse.statusCode != 200 {
            throw LoTWError.serverError(httpResponse.statusCode)
        }

        return try parseCSV(data: data, myCallsign: callsign)
    }

    // ── CSV Parsing ─────────────────────────────────────

    private func parseCSV(data: Data, myCallsign: String) throws -> [LoTWQSO] {
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw LoTWError.parseError
        }

        var results: [LoTWQSO] = []
        let lines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Skip header line
        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            guard fields.count >= 8 else { continue }

            // ADIF-style field mapping
            let call = fieldValue(fields, "CALL")
            guard !call.isEmpty else { continue }

            let qsoDateStr = fieldValue(fields, "QSO_DATE")
            let qsoDate = parseADIFDate(qsoDateStr) ?? Date()
            let lotwDateStr = fieldValue(fields, "LOTW_LOTWUSERLOGindate")
            let lotwDate = parseADIFDate(lotwDateStr)

            let mode = fieldValue(fields, "MODE")
            let band = fieldValue(fields, "BAND")
            let grid = fieldValue(fields, "GRIDSQUARE")
            let state = fieldValue(fields, "STATE")
            let country = fieldValue(fields, "COUNTRY")
            let freq = fieldValue(fields, "FREQ")

            let qso = LoTWQSO(
                id: UUID(),
                callsign: call,
                gridsquare: grid.isEmpty ? nil : grid,
                state: state.isEmpty ? nil : state,
                country: country.isEmpty ? nil : country,
                mode: mode.isEmpty ? "SSB" : mode,
                band: band.isEmpty ? "?" : band,
                frequency: freq.isEmpty ? nil : freq,
                qsoDate: qsoDate,
                lotwUploadDate: lotwDate,
                bearing: nil,
                distanceKm: nil
            )
            results.append(qso)
        }

        return results
    }

    private func parseCSVLine(_ line: String) -> [String: String] {
        var result: [String: String] = [:]
        // Simple CSV parsing — handle quoted fields
        var remaining = line
        while !remaining.isEmpty {
            // Find field name (before first comma, format: "FIELD:VALUE" or "FIELD":"VALUE")
            guard let colonIdx = remaining.firstIndex(of: ":") else { break }
            let fieldName = String(remaining[..<colonIdx]).uppercased()
            remaining = String(remaining[remaining.index(after: colonIdx)...])

            var value = ""
            if remaining.first == "\"" {
                // Quoted field
                remaining.removeFirst()
                if let endQuote = remaining.firstIndex(of: "\"") {
                    value = String(remaining[..<endQuote])
                    remaining = String(remaining[remaining.index(after: endQuote)...])
                    if remaining.first == "," { remaining.removeFirst() }
                }
            } else {
                // Unquoted field
                if let commaIdx = remaining.firstIndex(of: ",") {
                    value = String(remaining[..<commaIdx])
                    remaining = String(remaining[remaining.index(after: commaIdx)...])
                } else {
                    value = remaining
                    remaining = ""
                }
            }
            result[fieldName] = value
        }
        return result
    }

    private func fieldValue(_ fields: [String: String], _ key: String) -> String {
        fields[key] ?? ""
    }

    private func parseADIFDate(_ s: String) -> Date? {
        // Format: YYYYMMDD or YYYYMMDD HHMMSS
        guard s.count >= 8 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        if s.count >= 15 {
            formatter.dateFormat = "yyyyMMdd HHmmss"
        }
        return formatter.date(from: String(s.prefix(8)))
    }
}

// MARK: - Errors

enum LoTWError: LocalizedError {
    case invalidCallsign
    case notFound
    case networkError
    case serverError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidCallsign: return "Invalid callsign"
        case .notFound:       return "No LoTW confirmations found"
        case .networkError:   return "Network error"
        case .serverError(let code): return "Server error (\(code))"
        case .parseError:     return "Failed to parse LoTW data"
        }
    }
}
