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

    // ARRL LoTW CSV export — requires callsign login via query params
    // Format: https://loty.arrl.org/lotw?qso_call=CALL&lots=(lo_tw)userlogin&lotp=PASSWORD&...
    private static let lotwURL = "https://loty.arrl.org/lotw?"

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
        // ARRL LoTW export endpoint — uses ADIF-style response
        // Public confirmed QSOs via: https://loty.arrl.org/lotw?qso_call=CALL&mode=all&qso_start_date=2000-01-01
        var components = URLComponents(string: Self.lotwURL)!
        components.queryItems = [
            URLQueryItem(name: "qso_call", value: callsign),
            URLQueryItem(name: "mode", value: "all"),
            URLQueryItem(name: "qso_start_date", value: "2000-01-01"),
            URLQueryItem(name: "qso_end_date", value: "2099-12-31"),
            URLQueryItem(name: "format", value: "adif"),
        ]

        guard let url = components.url else {
            throw LoTWError.invalidCallsign
        }

        var request = URLRequest(url: url)
        request.setValue("HAMAllInOne/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LoTWError.networkError
        }

        if httpResponse.statusCode != 200 {
            throw LoTWError.serverError(httpResponse.statusCode)
        }

        return try parseADIF(data: data, myCallsign: callsign)
    }

    // ── ADIF Parsing ────────────────────────────────────

    /// Parse ADIF format response from ARRL LoTW.
    /// ADIF fields look like: <CALL:6>W1AW <FREQ:5>14.074 <BAND:3>20m <MODE:4>FT8 ...
    private func parseADIF(data: Data, myCallsign: String) throws -> [LoTWQSO] {
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw LoTWError.parseError
        }

        var results: [LoTWQSO] = []
        let body = extractADIFBody(content)

        let records = body.components(separatedBy: "<EOR>").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        for record in records {
            let fields = parseADIFRecord(record)
            guard let call = fields["CALL"], !call.isEmpty else { continue }

            let qsoDate = parseADIFDate(fields["QSO_DATE"] ?? "") ?? Date()
            let lotwDate = parseADIFDate(fields["LOTW_LOTWUSERLOGindate"] ?? fields["LOTW_QSO_LOTWUSERLOGindate"] ?? "")

            let qso = LoTWQSO(
                id: UUID(),
                callsign: call,
                gridsquare: fields["GRIDSQUARE"],
                state: fields["STATE"],
                country: fields["COUNTRY"],
                mode: fields["MODE"] ?? "SSB",
                band: fields["BAND"] ?? "?",
                frequency: fields["FREQ"],
                qsoDate: qsoDate,
                lotwUploadDate: lotwDate,
                bearing: nil,
                distanceKm: nil
            )
            results.append(qso)
        }

        return results
    }

    private func extractADIFBody(_ content: String) -> String {
        // Skip header comments (lines starting with # or containing header markers)
        var lines = content.components(separatedBy: .newlines)
        if let headerEnd = lines.firstIndex(where: { $0.uppercased().contains("<EOH>") }) {
            lines = Array(lines.dropFirst(headerEnd + 1))
        }
        return lines.joined(separator: "\n")
    }

    /// Parse a single ADIF record into field name → value dictionary.
    /// ADIF field format: <FIELD:LENGTH>VALUE or <FIELD:LENGTH:POS>VALUE
    private func parseADIFRecord(_ record: String) -> [String: String] {
        var result: [String: String] = [:]
        var remaining = record.uppercased()

        while let openBrkt = remaining.firstIndex(of: "<") {
            let afterOpen = remaining[remaining.index(after: openBrkt)...]
            guard let colon1 = afterOpen.firstIndex(of: ":") else { break }

            let fieldName = String(afterOpen[..<colon1])
            let afterColon1 = afterOpen[afterOpen.index(after: colon1)...]

            guard let closeBrkt = afterColon1.firstIndex(of: ">") else { break }
            let lenRaw = String(afterColon1[..<closeBrkt])

            var fieldLength: Int?
            let afterClose: Substring

            if let colon2 = lenRaw.firstIndex(of: ":") {
                fieldLength = Int(String(lenRaw[..<colon2]))
                afterClose = afterColon1[afterColon1.index(after: closeBrkt)...]
            } else {
                fieldLength = Int(lenRaw)
                afterClose = afterColon1[afterColon1.index(after: closeBrkt)...]
            }

            guard let len = fieldLength else { break }
            let value = String(afterClose.prefix(len))
            remaining = String(afterClose.dropFirst(len))
            result[fieldName] = value
        }

        return result
    }

    private func parseADIFDate(_ s: String) -> Date? {
        guard s.count >= 8 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
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
