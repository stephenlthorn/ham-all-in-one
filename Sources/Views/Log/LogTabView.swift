import SwiftUI

struct LogTabView: View {
    @EnvironmentObject var qsoStore: QSOStore
    @EnvironmentObject var locationService: LocationService
    @State private var showingNewQSO = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if qsoStore.qsos.isEmpty {
                    emptyState
                } else {
                    qsoList
                }
            }
            .navigationTitle("QSO Log")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewQSO = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingNewQSO) {
                NewQSOSheet()
            }
            .searchable(text: $searchText, prompt: "Search callsigns...")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No QSOs Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap + to log your first contact")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var qsoList: some View {
        List {
            Section {
                statsBar
            }

            Section("Recent Contacts") {
                ForEach(filteredQSOs) { qso in
                    QSORow(qso: qso)
                }
                .onDelete(perform: deleteQSOs)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var filteredQSOs: [QSO] {
        if searchText.isEmpty { return qsoStore.qsos }
        return qsoStore.qsos.filter { $0.callsign.localizedCaseInsensitiveContains(searchText) }
    }

    private var statsBar: some View {
        HStack(spacing: 20) {
            stat("Today", value: "\(todayCount)")
            Divider()
            stat("This Month", value: "\(monthCount)")
            Divider()
            stat("Total", value: "\(qsoStore.qsos.count)")
            Divider()
            stat("Callsigns", value: "\(qsoStore.uniqueCallsigns().count)")
        }
        .padding(.vertical, 8)
        .font(.caption)
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundColor(.orange)
            Text(label)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var todayCount: Int {
        qsoStore.qsos(for: Date()).count
    }

    private var monthCount: Int {
        qsoStore.qsosThisMonth().count
    }

    private func deleteQSOs(at offsets: IndexSet) {
        for idx in offsets {
            qsoStore.delete(filteredQSOs[idx])
        }
    }
}

// MARK: - QSO Row

struct QSORow: View {
    let qso: QSO

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(qso.callsign)
                        .font(.headline.monospaced())
                    if qso.satelliteName != nil {
                        Text("🛰")
                    }
                    if qso.repeaterCallsign != nil {
                        Text("📡")
                    }
                }
                HStack(spacing: 8) {
                    if let mode = qso.mode {
                        Text(mode)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(4)
                    }
                    if let freq = qso.frequency {
                        Text(freq)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let grid = qso.grid {
                        Text(grid)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let rst = qso.rstSent {
                    Text("RST: \(rst)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: qso.datetime)
    }
}

// MARK: - New QSO Sheet

struct NewQSOSheet: View {
    @EnvironmentObject var qsoStore: QSOStore
    @EnvironmentObject var locationService: LocationService
    @Environment(\.dismiss) private var dismiss

    @State private var callsign = ""
    @State private var frequency = ""
    @State private var selectedModeStr = HamMode.fm.rawValue
    @State private var rstSent = "59"
    @State private var rstReceived = "59"
    @State private var notes = ""
    @State private var grid = ""
    @State private var repeaterCallsign = ""
    @State private var satelliteName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lookupResult: CallsignRecord?

    var body: some View {
        NavigationStack {
            Form {
                Section("Callsign") {
                    HStack {
                        TextField("e.g. K4ABC", text: $callsign)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.title3.monospaced())
                            .onChange(of: callsign) { _, newVal in
                                if newVal.count >= 3 {
                                    Task { await lookupCallsign() }
                                }
                            }
                        if isLoading {
                            ProgressView()
                        }
                    }

                    if let result = lookupResult {
                        Section("Callsign Info") {
                            if let name = result.operatorName {
                                LabeledContent("Name", value: name)
                            }
                            if let cls = result.licenseClass {
                                LabeledContent("Class", value: cls)
                            }
                            if let city = result.city, let state = result.state {
                                LabeledContent("QTH", value: "\(city), \(state)")
                            }
                            if let gridResult = result.grid {
                                LabeledContent("Grid", value: gridResult)
                            }
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section("Contact Details") {
                    Picker("Mode", selection: $selectedModeStr) {
                        ForEach(HamMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    TextField("Frequency (e.g. 146.52 MHz)", text: $frequency)
                        .keyboardType(.decimalPad)
                    TextField("Grid (e.g. FM05)", text: $grid)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section("RST") {
                    HStack {
                        Text("Sent").frame(width: 60)
                        TextField("RST Sent", text: $rstSent)
                            .keyboardType(.numberPad)
                        Text("Received").frame(width: 70)
                        TextField("RST Rcvd", text: $rstReceived)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Optional") {
                    TextField("Repeater Callsign", text: $repeaterCallsign)
                        .textInputAutocapitalization(.characters)
                    TextField("Satellite Name (e.g. ISS)", text: $satelliteName)
                        .textInputAutocapitalization(.characters)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let loc = locationService.currentLocation {
                    Section {
                        LabeledContent("My Grid", value: locationService.currentGrid ?? "—")
                    }
                }
            }
            .navigationTitle("New QSO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { logQSO() }
                        .disabled(callsign.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func lookupCallsign() async {
        let trimmed = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count >= 3 else { return }
        isLoading = true
        errorMessage = nil
        lookupResult = nil

        do {
            let result = try await CallsignService.shared.lookup(callsign: trimmed)
            await MainActor.run {
                lookupResult = result
                if let g = result.grid, grid.isEmpty { grid = g }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run { isLoading = false }
    }

    private func logQSO() {
        let qso = QSO(
            callsign: callsign.uppercased().trimmingCharacters(in: .whitespaces),
            datetime: Date(),
            frequency: frequency.isEmpty ? nil : frequency,
            mode: selectedModeStr,
            rstSent: rstSent.isEmpty ? nil : rstSent,
            rstReceived: rstReceived.isEmpty ? nil : rstReceived,
            notes: notes.isEmpty ? nil : notes,
            grid: grid.isEmpty ? nil : grid.uppercased(),
            repeaterCallsign: repeaterCallsign.isEmpty ? nil : repeaterCallsign.uppercased(),
            satelliteName: satelliteName.isEmpty ? nil : satelliteName,
            operatorCallsign: UserDefaults.standard.string(forKey: "ham.myCallsign") ?? "N0CALL"
        )
        qsoStore.add(qso)
        dismiss()
    }
}

#Preview {
    LogTabView()
        .environmentObject(QSOStore())
        .environmentObject(LocationService())
}
