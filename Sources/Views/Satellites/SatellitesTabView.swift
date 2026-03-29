import SwiftUI

struct SatellitesTabView: View {
    @EnvironmentObject var satelliteStore: SatelliteStore
    @EnvironmentObject var locationService: LocationService
    @State private var selectedSatellite: Satellite?
    @State private var showingPassDetail: SatellitePass?
    @State private var isLoadingPasses = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task {
                            isLoadingPasses = true
                            await satelliteStore.loadTLES()
                            if let loc = locationService.currentLocation {
                                satelliteStore.calculatePasses(from: loc)
                            }
                            isLoadingPasses = false
                        }
                    } label: {
                        HStack {
                            Text("Refresh Passes")
                            Spacer()
                            if isLoadingPasses {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoadingPasses)

                    if let loc = locationService.currentLocation {
                        Text("Passes for your location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Location needed for pass predictions")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if !satelliteStore.upcomingPasses.isEmpty {
                    Section("Upcoming Passes") {
                        ForEach(satelliteStore.upcomingPasses.prefix(10)) { pass in
                            PassRow(pass: pass)
                                .onTapGesture {
                                    showingPassDetail = pass
                                }
                        }
                    }
                }

                Section("Active Satellites") {
                    ForEach(satellites) { sat in
                        SatelliteRow(satellite: sat)
                            .onTapGesture {
                                selectedSatellite = sat
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Satellites")
            .sheet(item: $showingPassDetail) { pass in
                PassDetailSheet(pass: pass)
            }
        }
        .task {
            if let loc = locationService.currentLocation {
                satelliteStore.calculatePasses(from: loc)
            }
        }
    }

    private var satellites: [Satellite] {
        satelliteStore.satellites.filter { $0.isActive }
    }
}

// MARK: - Pass Row

struct PassRow: View {
    let pass: SatellitePass

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("🛰 \(pass.satelliteName)")
                        .font(.headline)
                    Spacer()
                    qualityBadge
                }

                HStack(spacing: 12) {
                    Label(formattedTime(pass.aosTime), systemImage: "arrow.up.circle")
                        .font(.caption)
                    Label(formattedTime(pass.losTime), systemImage: "arrow.down.circle")
                        .font(.caption)
                    Label(formattedDuration, systemImage: "clock")
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                HStack {
                    Text("Max elevation: \(Int(pass.maxElevation))°")
                        .font(.caption2)
                    Text("AOS Az: \(Int(pass.aosAzimuth))°")
                        .font(.caption2)
                    Text("LOS Az: \(Int(pass.losAzimuth))°")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var qualityBadge: some View {
        Text(pass.quality.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(qualityColor.opacity(0.2))
            .foregroundColor(qualityColor)
            .cornerRadius(6)
    }

    private var qualityColor: Color {
        switch pass.quality {
        case .excellent: return .green
        case .good: return .yellow
        case .fair: return .orange
        case .poor: return .red
        }
    }

    private var formattedDuration: String {
        let mins = Int(pass.duration / 60)
        return "\(mins) min"
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Satellite Row

struct SatelliteRow: View {
    let satellite: Satellite

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(satellite.name)
                    .font(.headline)
                if satellite.tleLine1 != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                Spacer()
                Circle()
                    .fill(satellite.isActive ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }

            HStack(spacing: 12) {
                if let uplink = satellite.uplinkMHz {
                    VStack(alignment: .leading) {
                        Text("Uplink")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.3f MHz", uplink))
                            .font(.caption.monospaced())
                    }
                }
                if let downlink = satellite.downlinkMHz {
                    VStack(alignment: .leading) {
                        Text("Downlink")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.3f MHz", downlink))
                            .font(.caption.monospaced())
                    }
                }
                if let mode = satellite.mode {
                    VStack(alignment: .leading) {
                        Text("Mode")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(mode)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Pass Detail Sheet

struct PassDetailSheet: View {
    let pass: SatellitePass
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("🛰 \(pass.satelliteName)")
                        .font(.largeTitle.bold())
                    Text(pass.quality.rawValue)
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(qualityColor.opacity(0.2))
                        .foregroundColor(qualityColor)
                        .cornerRadius(8)
                }

                // Timing
                HStack(spacing: 32) {
                    VStack {
                        Label("AOS", systemImage: "arrow.up.circle.fill")
                            .font(.caption)
                        Text(formattedTime(pass.aosTime))
                            .font(.title3.monospaced())
                        Text("az \(Int(pass.aosAzimuth))°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Label("MAX", systemImage: "arrow.up.to.line")
                            .font(.caption)
                        Text("\(Int(pass.maxElevation))°")
                            .font(.title3.monospaced())
                    }

                    VStack {
                        Label("LOS", systemImage: "arrow.down.circle.fill")
                            .font(.caption)
                        Text(formattedTime(pass.losTime))
                            .font(.title3.monospaced())
                        Text("az \(Int(pass.losAzimuth))°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Duration
                HStack {
                    Image(systemName: "clock")
                    Text("Duration: \(Int(pass.duration / 60)) min")
                }
                .font(.headline)

                // Add to calendar button
                Button {
                    addToCalendar()
                } label: {
                    Label("Add to Calendar", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .navigationTitle("Pass Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var qualityColor: Color {
        switch pass.quality {
        case .excellent: return .green
        case .good: return .yellow
        case .fair: return .orange
        case .poor: return .red
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func addToCalendar() {
        // Calendar integration would go here
    }
}

#Preview {
    SatellitesTabView()
        .environmentObject(SatelliteStore())
        .environmentObject(LocationService())
}
