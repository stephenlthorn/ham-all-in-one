import Foundation
import Combine

// MARK: - QSO Store

@MainActor
final class QSOStore: ObservableObject {
    @Published private(set) var qsos: [QSO] = []
    @Published private(set) var isLoading = false

    private let userDefaultsKey = "ham.qsos"

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([QSO].self, from: data) else {
            qsos = []
            return
        }
        qsos = decoded.sorted { $0.datetime > $1.datetime }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(qsos) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    func add(_ qso: QSO) {
        qsos.insert(qso, at: 0)
        persist()
    }

    func update(_ qso: QSO) {
        guard let idx = qsos.firstIndex(where: { $0.id == qso.id }) else { return }
        qsos[idx] = qso
        persist()
    }

    func delete(_ qso: QSO) {
        qsos.removeAll { $0.id == qso.id }
        persist()
    }

    func qsos(for date: Date) -> [QSO] {
        let calendar = Calendar.current
        return qsos.filter { calendar.isDate($0.datetime, inSameDayAs: date) }
    }

    func qsosThisMonth() -> [QSO] {
        let calendar = Calendar.current
        let now = Date()
        return qsos.filter {
            calendar.component(.month, from: $0.datetime) == calendar.component(.month, from: now) &&
            calendar.component(.year, from: $0.datetime) == calendar.component(.year, from: now)
        }
    }

    // MARK: - Awards helpers

    func uniqueCallsigns() -> Set<String> {
        Set(qsos.map { $0.callsign.uppercased() })
    }

    func qsosWithGrid() -> [QSO] {
        qsos.filter { $0.grid != nil }
    }

    // MARK: - ADIF Export

    /// Export all QSOs as an ADIF 3.1.4 string for LoTW, QRZ, etc.
    func exportADIF(myCallsign: String) -> String {
        var adif = """
        ADIF Export from HAM All In One
        <ADIF_VER:5>3.1.4
        <PROGRAMID:14>HAMAllInOne
        <PROGRAMVERSION:3>1.0
        <EOH>

        """

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmmss"

        for qso in qsos {
            var record = ""

            // Required fields
            record += adifField("CALL", qso.callsign)
            record += adifField("QSO_DATE", dateFormatter.string(from: qso.datetime))
            record += adifField("TIME_ON", timeFormatter.string(from: qso.datetime))
            record += adifField("STATION_CALLSIGN", myCallsign)
            record += adifField("OPERATOR", myCallsign)

            // Mode and band
            if let mode = qso.mode { record += adifField("MODE", mode) }
            if let freq = qso.frequency {
                let mhz = freq.replacingOccurrences(of: " MHz", with: "").replacingOccurrences(of: " MHz", with: "")
                record += adifField("FREQ", mhz)
                record += adifField("BAND", bandFromFreq(mhz))
            }

            // RST
            if let rst = qso.rstSent { record += adifField("RST_SENT", rst) }
            if let rst = qso.rstReceived { record += adifField("RST_RCVD", rst) }

            // Grid
            if let grid = qso.grid { record += adifField("GRIDSQUARE", grid) }

            // Repeater
            if let repeater = qso.repeaterCallsign { record += adifField("SRL_CALL", repeater) }

            // Satellite
            if let sat = qso.satelliteName {
                record += adifField("SAT_NAME", sat)
                record += adifField("PROP_MODE", "SAT")
            }

            // Notes
            if let notes = qso.notes {
                record += adifField("COMMENT", notes)
            }

            record += adifField("APP_HAMALLINONE_VERSION", "1.0")

            adif += record + "\n"
        }

        return adif
    }

    private func adifField(_ name: String, _ value: String) -> String {
        "<\(name):\(value.count)>\(value)"
    }

    private func bandFromFreq(_ freqMHz: String) -> String {
        guard let f = Double(freqMHz) else { return "?" }
        switch f {
        case  1.8...2.0:   return "160m"
        case  3.5...4.0:   return "80m"
        case  5.3...5.4:   return "60m"
        case  7.0...7.3:   return "40m"
        case 10.1...10.15: return "30m"
        case 14.0...14.35: return "20m"
        case 18.068...18.168: return "17m"
        case 21.0...21.45: return "15m"
        case 24.89...24.99: return "12m"
        case 28.0...29.7:  return "10m"
        case 50.0...54.0:  return "6m"
        case 144.0...148.0: return "2m"
        case 420.0...450.0: return "70cm"
        default: return "?"
        }
    }

    /// Share QSO log as a text summary.
    func shareText() -> String {
        var text = "HAM All In One QSO Log\n"
        text += "Exported: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))\n"
        text += "Total QSOs: \(qsos.count)\n\n"

        for qso in qsos.prefix(20) {
            let date = DateFormatter.localizedString(from: qso.datetime, dateStyle: .short, timeStyle: .short)
            var line = "\(date) | \(qso.callsign)"
            if let mode = qso.mode { line += " | \(mode)" }
            if let freq = qso.frequency { line += " | \(freq)" }
            if let grid = qso.grid { line += " | \(grid)" }
            text += line + "\n"
        }

        if qsos.count > 20 {
            text += "\n... and \(qsos.count - 20) more"
        }

        return text
    }
}
