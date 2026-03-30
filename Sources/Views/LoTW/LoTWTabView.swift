import SwiftUI

struct LoTWTabView: View {
    @EnvironmentObject var lotwStore: LoTWStore
    @State private var searchCallsign = ""
    @State private var selectedMode: String = "All"
    @State private var selectedBand: String = "All"

    private let modes = ["All", "CW", "SSB", "FT8", "FT4", "RTTY", "PSK31", "AM", "FM"]
    private let bands = ["All", "160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m", "6m", "2m", "70cm"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search header
                VStack(spacing: 8) {
                    HStack {
                        TextField("Callsign", text: $searchCallsign)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                            .textFieldStyle(.roundedBorder)

                        Button {
                            Task { await lotwStore.fetchConfirmations(callsign: searchCallsign) }
                        } label: {
                            if lotwStore.isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                        }
                        .disabled(searchCallsign.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if let lastFetched = lotwStore.lastFetched {
                        Text("Last fetched: \(lastFetched, style: .relative) ago")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))

                // Mode/Band filter
                HStack {
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(modes, id: \.self) { Text($0) }
                    }
                    .labelsHidden()

                    Divider().frame(height: 20)

                    Picker("Band", selection: $selectedBand) {
                        ForEach(bands, id: \.self) { Text($0) }
                    }
                    .labelsHidden()
                }
                .font(.caption)
                .padding(.horizontal)
                .padding(.vertical, 6)

                // QSO list
                List {
                    if let error = lotwStore.errorMessage {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    let filtered = filteredQSOs
                    if filtered.isEmpty && !lotwStore.isLoading {
                        ContentUnavailableView {
                            Label("No Confirmations", systemImage: "checkmark.seal")
                        } description: {
                            if lotwStore.qsos.isEmpty {
                                Text("Enter a callsign above to fetch LoTW confirmations")
                            } else {
                                Text("No QSOs match the current filter")
                            }
                        }
                    } else {
                        Section("Confirmed QSOs (\(filtered.count))") {
                            ForEach(filtered) { qso in
                                LoTWQSORow(qso: qso)
                            }
                        }

                        if !lotwStore.qsos.isEmpty {
                            Section {
                                LoTWStatsCard(qsos: lotwStore.qsos)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("LoTW")
        }
    }

    private var filteredQSOs: [LoTWStore.LoTWQSO] {
        lotwStore.qsos.filter { qso in
            let modeMatch = selectedMode == "All" || qso.mode.uppercased() == selectedMode.uppercased()
            let bandMatch = selectedBand == "All" || qso.band == selectedBand
            return modeMatch && bandMatch
        }
    }
}

// MARK: - LoTW QSO Row

struct LoTWQSORow: View {
    let qso: LoTWStore.LoTWQSO

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(qso.callsign)
                    .font(.headline.monospaced())
                    .foregroundColor(.green)

                Spacer()

                VStack(alignment: .trailing) {
                    Text(qso.band)
                        .font(.caption.bold())
                    Text(qso.mode)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                if let grid = qso.gridsquare {
                    Label(grid, systemImage: "square.grid.3x3")
                        .font(.caption.monospaced())
                }

                if let state = qso.state {
                    Text(state)
                        .font(.caption)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(3)
                }

                if let country = qso.country {
                    Text(country)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(qso.qsoDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - LoTW Stats Card

struct LoTWStatsCard: View {
    let qsos: [LoTWStore.LoTWQSO]

    private var bandCounts: [(band: String, count: Int)] {
        Dictionary(grouping: qsos, by: { $0.band })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .map { (band: $0.key, count: $0.value) }
    }

    private var modeCounts: [(mode: String, count: Int)] {
        Dictionary(grouping: qsos, by: { $0.mode })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .map { (mode: $0.key, count: $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Statistics")
                    .font(.headline)
                Spacer()
                Text("\(qsos.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("By Band")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    ForEach(bandCounts.prefix(5), id: \.band) { item in
                        HStack {
                            Text(item.band)
                                .font(.caption.monospaced())
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("By Mode")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    ForEach(modeCounts.prefix(5), id: \.mode) { item in
                        HStack {
                            Text(item.mode)
                                .font(.caption.monospaced())
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LoTWTabView()
        .environmentObject(LoTWStore())
}
