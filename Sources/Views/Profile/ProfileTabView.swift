import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var locationService: LocationService
    @State private var myCallsign = UserDefaults.standard.string(forKey: "ham.myCallsign") ?? ""
    @State private var lookupResult: CallsignRecord?
    @State private var lookupHistory: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                // My Station
                Section("My Station") {
                    HStack {
                        TextField("Your Callsign", text: $myCallsign)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.title2.monospaced())
                            .onChange(of: myCallsign) { _, newVal in
                                let upper = newVal.uppercased()
                                UserDefaults.standard.set(upper, forKey: "ham.myCallsign")
                            }
                        if !myCallsign.isEmpty {
                            Button {
                                Task { await lookupMyCallsign() }
                            } label: {
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                            }
                        }
                    }

                    if let result = lookupResult {
                        CallsignInfoCard(record: result)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // My Location
                Section("My Location") {
                    if let grid = locationService.currentGrid {
                        LabeledContent("Grid", value: grid)
                    }
                    if let loc = locationService.currentLatLon {
                        LabeledContent("Lat/Lon", value: String(format: "%.4f, %.4f", loc.lat, loc.lon))
                    }
                    Button("Update Location") {
                        locationService.requestIfNeeded()
                    }
                }

                // Lookup History
                if !lookupHistory.isEmpty {
                    Section("Recent Lookups") {
                        ForEach(lookupHistory, id: \.self) { call in
                            HStack {
                                Text(call)
                                    .font(.headline.monospaced())
                                Spacer()
                                Button {
                                    Task {
                                        myCallsign = call
                                        await lookupMyCallsign()
                                    }
                                } label: {
                                    Image(systemName: "arrow.up.circle")
                                }
                            }
                        }
                    }
                }

                // App Settings
                Section("Settings") {
                    NavigationLink("Notifications") {
                        NotificationSettingsView()
                    }
                    NavigationLink("Units") {
                        UnitsSettingsView()
                    }
                    NavigationLink("Data") {
                        DataManagementView()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                    Link(destination: URL(string: "https://github.com/stephenlthorn/ham-all-in-one")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
        }
    }

    private func lookupMyCallsign() async {
        let trimmed = myCallsign.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        lookupResult = nil

        do {
            let result = try await CallsignService.shared.lookup(callsign: trimmed)
            await MainActor.run {
                lookupResult = result
                if !lookupHistory.contains(trimmed) {
                    lookupHistory.insert(trimmed, at: 0)
                    if lookupHistory.count > 10 {
                        lookupHistory.removeLast()
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run { isLoading = false }
    }
}

// MARK: - Callsign Info Card

struct CallsignInfoCard: View {
    let record: CallsignRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    if let name = record.operatorName {
                        Text(name)
                            .font(.headline)
                    }
                    if let cls = record.licenseClass {
                        Text(cls)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                Spacer()
                if let grid = record.grid {
                    VStack {
                        Text(grid)
                            .font(.title3.monospaced().bold())
                        Text("Grid")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let city = record.city, let state = record.state {
                Label("\(city), \(state)", systemImage: "mappin")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let lat = record.latitude, let lon = record.longitude {
                Label(String(format: "%.4f, %.4f", lat, lon), systemImage: "location")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let url = record.qrZURL, let qrzURL = URL(string: url) {
                Link("View on QRZ.com", destination: qrzURL)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sub-views

struct NotificationSettingsView: View {
    @State private var satelliteAlerts = true
    @State private var repeaterAlerts = false
    @State private var qsoReminders = false

    var body: some View {
        List {
            Section("Satellite Passes") {
                Toggle("Pass start alerts", isOn: $satelliteAlerts)
            }
            Section("Repeaters") {
                Toggle("Nearby repeater alerts", isOn: $repeaterAlerts)
            }
            Section("Logging") {
                Toggle("QSO reminders", isOn: $qsoReminders)
            }
        }
        .navigationTitle("Notifications")
    }
}

struct UnitsSettingsView: View {
    @State private var useMetric = false
    @State private var use24Hour = true

    var body: some View {
        List {
            Section {
                Toggle("Use Metric (km)", isOn: $useMetric)
                Toggle("24-Hour Time", isOn: $use24Hour)
            }
        }
        .navigationTitle("Units")
    }
}

struct DataManagementView: View {
    @EnvironmentObject var qsoStore: QSOStore
    @State private var showingExport = false
    @State private var showingClearConfirm = false

    var body: some View {
        List {
            Section {
                Button("Export QSOs (CSV)") {
                    exportQSOs()
                }
                Button("Import ADIF Log") {
                    // ADIF import
                }
            }

            Section {
                Button("Clear QSO Log", role: .destructive) {
                    showingClearConfirm = true
                }
                .confirmationDialog("Clear all QSOs?", isPresented: $showingClearConfirm) {
                    Button("Clear All", role: .destructive) {
                        // Clear
                    }
                }
            }
        }
        .navigationTitle("Data")
    }

    private func exportQSOs() {
        // Generate CSV from qsoStore.qsos
        // Share via UIActivityViewController
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(LocationService())
}
