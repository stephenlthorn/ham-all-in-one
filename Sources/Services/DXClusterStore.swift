import Foundation
import Network

/// DX Cluster client — connects to public amateur radio DX cluster servers
/// via raw TCP/Telnet to receive real-time spotted stations.
///
@MainActor
final class DXClusterStore: ObservableObject {
    /// A single DX spot from the cluster.
    struct DXSpot: Identifiable, Equatable {
        let id: UUID
        let callsign: String
        let frequency: Double       // kHz
        let spottedCallsign: String
        let notes: String?
        let timestamp: Date
        let dxGrid: String?
        let source: String

        var frequencyMHz: Double { frequency / 1000.0 }

        var band: String {
            let mhz = frequencyMHz
            let ranges: [String: ClosedRange<Double>] = [
                "160m":  1.8...2.0,   "80m":   3.5...4.0,
                "40m":   7.0...7.3,   "30m":  10.1...10.15,
                "20m":  14.0...14.35, "17m":  18.068...18.168,
                "15m":  21.0...21.45, "12m":  24.89...24.99,
                "10m":  28.0...29.7,   "6m":   50.0...54.0,
                "2m":  144.0...148.0,
            ]
            for (b, range) in ranges {
                if range.contains(mhz) { return b }
            }
            return "???"
        }

        static func == (lhs: DXSpot, rhs: DXSpot) -> Bool {
            lhs.callsign == rhs.callsign &&
            lhs.frequency == rhs.frequency &&
            lhs.spottedCallsign == rhs.spottedCallsign
        }
    }

    @Published private(set) var spots: [DXSpot] = []
    @Published private(set) var isConnected = false
    @Published private(set) var connectionState: String = "Disconnected"
    @Published private(set) var errorMessage: String?
    @Published var selectedBand: String = "All"

    /// Public DX cluster telnet servers
    private let servers: [(host: String, port: Int)] = [
        ("dxc.ac3yy.com",    7300),
        ("dxc.n4dxc.org",     8000),
        ("dxcluster.vucc.net", 23),
    ]

    private var readerTask: Task<Void, Never>?
    private var subscribedCallsign: String = ""
    private var connection: NWConnection?

    private var receivedBuffer = Data()

    // ── Public API ─────────────────────────────────────────

    func connect(myCallsign: String) async {
        guard readerTask == nil else { return }
        subscribedCallsign = myCallsign

        for server in servers {
            connectionState = "Connecting to \(server.host)..."
            do {
                try await connectToServer(host: server.host, port: server.port)
                return
            } catch {
                connectionState = "Trying next..."
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        connectionState = "Failed"
        errorMessage = "No DX cluster servers reachable"
    }

    func disconnect() {
        readerTask?.cancel()
        readerTask = nil
        connection?.cancel()
        connection = nil
        isConnected = false
        connectionState = "Disconnected"
    }

    var filteredSpots: [DXSpot] {
        var result = spots.filter {
            Date().timeIntervalSince($0.timestamp) < 2 * 3600
        }

        if selectedBand != "All" {
            let ranges: [String: ClosedRange<Double>] = [
                "160m":  1.8...2.0,  "80m":   3.5...4.0,
                "40m":   7.0...7.3,  "30m":  10.1...10.15,
                "20m":  14.0...14.35,"17m":  18.068...18.168,
                "15m":  21.0...21.45,"12m":  24.89...24.99,
                "10m":  28.0...29.7,  "6m":   50.0...54.0,
                "2m":  144.0...148.0,
            ]
            if let range = ranges[selectedBand] {
                result = result.filter { range.contains($0.frequencyMHz) }
            }
        }

        return result.sorted { $0.timestamp > $1.timestamp }
    }

    // ── Connection ────────────────────────────────────────

    private func connectToServer(host: String, port: Int) async throws {
        let endpoint = NWEndpoint.hostPort(
            host: .init(host),
            port: .init(integerLiteral: UInt16(port))
        )
        connection = NWConnection(to: endpoint, using: .tcp)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var hasResumed = false
            let lock = NSLock()

            connection!.stateUpdateHandler = { state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        lock.lock(); defer { lock.unlock() }
                        guard !hasResumed else { return }
                        hasResumed = true
                        continuation.resume()
                    case .failed(let error):
                        lock.lock(); defer { lock.unlock() }
                        guard !hasResumed else { return }
                        hasResumed = true
                        continuation.resume(throwing: error)
                    case .cancelled:
                        lock.lock(); defer { lock.unlock() }
                        guard !hasResumed else { return }
                        hasResumed = true
                        continuation.resume(throwing: DXClusterError.cancelled)
                    default:
                        break
                    }
                }
            }
            connection!.start(queue: .global(qos: .userInitiated))
        }

        isConnected = true
        connectionState = "Connected"

        // Login
        try await send("\(subscribedCallsign)\r\n")
        try await Task.sleep(nanoseconds: 500_000_000)
        try await send("\r\n")
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Start read loop
        readerTask = Task { [weak self] in
            guard let self = self else { return }
            await self.readLoop()
        }
    }

    private func send(_ data: String) async throws {
        guard let connection = connection else { throw DXClusterError.notConnected }
        let bytes = Array(data.utf8)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var hasResumed = false
            let lock = NSLock()
            connection.send(content: Data(bytes), completion: .contentProcessed { error in
                lock.lock(); defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                if let e = error { continuation.resume(throwing: e) }
                else { continuation.resume() }
            })
        }
    }

    private func readLoop() async {
        guard let connection = connection else { return }

        while !Task.isCancelled {
            if connection.state != .ready { break }

            let data: Data? = await withCheckedContinuation { continuation in
                var didResume = false
                let lock = NSLock()

                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, isComplete, error in
                    lock.lock(); defer { lock.unlock() }
                    guard !didResume else { return }
                    didResume = true
                    if isComplete || error != nil {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: content ?? Data())
                    }
                }

                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    lock.lock(); defer { lock.unlock() }
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume(returning: nil)
                }
            }

            if let d = data, !d.isEmpty {
                processReceivedData(d)
            } else {
                break
            }

            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        await MainActor.run { disconnect() }
    }

    // ── Parse ─────────────────────────────────────────────

    private func processReceivedData(_ data: Data) {
        receivedBuffer.append(data)

        while let newlineIndex = receivedBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = Data(receivedBuffer[..<newlineIndex])
            receivedBuffer = Data(receivedBuffer[receivedBuffer.index(after: newlineIndex)...])

            if let line = String(data: lineData, encoding: .utf8) ?? String(data: lineData, encoding: .ascii) {
                handleLine(line)
            }
        }
    }

    private func handleLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.hasPrefix("DX de ") else { return }

        if let spot = parseDXLine(trimmed) {
            spots.removeAll { $0.spottedCallsign == spot.spottedCallsign && $0.frequency == spot.frequency }
            spots.insert(spot, at: 0)
            if spots.count > 200 { spots = Array(spots.prefix(200)) }
        }
    }

    private func parseDXLine(_ line: String) -> DXSpot? {
        // "DX de CALLSIGN: FREQ NOTES <-- HHMMZ>"
        let body = line.dropFirst(7)
        guard let colonIdx = body.firstIndex(of: ":") else { return nil }

        let caller = String(body[..<colonIdx]).trimmingCharacters(in: .whitespaces)
        let rest = String(body[body.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
        let parts = rest.split(separator: " ", maxSplits: 10)

        guard parts.count >= 2,
              let freqKHz = Double(parts[0].filter { $0.isNumber || $0 == "." }) else { return nil }

        var dxCall = ""
        var notes = ""
        var dxGrid: String?
        var timestamp = Date()

        for part in parts.dropFirst() {
            let s = String(part)

            // Time: <HHMMZ>
            if s.hasPrefix("<") && s.hasSuffix("Z>") {
                let t = s.dropFirst(1).dropLast(2)
                if let hm = parseHM(t) { timestamp = hm }
                continue
            }

            // Grid (4-6 alphanumeric starting with letter)
            if s.count >= 4, s.allSatisfy({ $0.isLetter || $0.isNumber }), s.first?.isLetter == true {
                dxGrid = s
                continue
            }

            if dxCall.isEmpty {
                dxCall = s
            } else {
                notes += (notes.isEmpty ? "" : " ") + s
            }
        }

        guard !dxCall.isEmpty, freqKHz > 0 else { return nil }

        return DXSpot(
            id: UUID(),
            callsign: caller,
            frequency: freqKHz,
            spottedCallsign: dxCall,
            notes: notes.isEmpty ? nil : notes,
            timestamp: timestamp,
            dxGrid: dxGrid,
            source: "DX Cluster"
        )
    }

    private func parseHM(_ s: Substring) -> Date? {
        guard s.count >= 4 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: String(s.prefix(4)))
    }
}

// MARK: - Errors

enum DXClusterError: LocalizedError {
    case notConnected
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected"
        case .cancelled:   return "Cancelled"
        }
    }
}
