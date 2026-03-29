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
}
