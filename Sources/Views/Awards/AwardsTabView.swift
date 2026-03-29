import SwiftUI

struct AwardsTabView: View {
    @EnvironmentObject var qsoStore: QSOStore
    @State private var selectedAward: AwardType = .dxcc

    enum AwardType: String, CaseIterable {
        case dxcc = "DXCC"
        case vucc = "VUCC"
        case was = "WAS"
        case county = "County Hunter"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Award", selection: $selectedAward) {
                    ForEach(AwardType.allCases, id: \.self) { award in
                        Text(award.rawValue).tag(award)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    switch selectedAward {
                    case .dxcc:  dxccView
                    case .vucc:  vuccView
                    case .was:   wasView
                    case .county: countyView
                    }
                }
            }
            .navigationTitle("Awards")
        }
    }

    // MARK: - DXCC

    private var dxccView: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack {
                            Text("\(workedCountries.count)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text("of 100+")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .padding()

                    Text("DXCC Progress")
                        .font(.headline)
                    Text("\(workedCountries.count) countries worked")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Section("Worked Countries") {
                ForEach(workedCountries.sorted(), id: \.self) { country in
                    Label(country, systemImage: "globe")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - VUCC

    private var vuccView: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: vuccProgress)
                            .stroke(Color.purple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack {
                            Text("\(workedGrids.count)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text("of 100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .padding()

                    Text("VUCC Progress")
                        .font(.headline)
                    Text("\(workedGrids.count) grid squares confirmed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Section("Worked Grids") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 4) {
                    ForEach(workedGrids.sorted(), id: \.self) { grid in
                        Text(grid)
                            .font(.caption2.monospaced())
                            .padding(4)
                            .frame(minWidth: 60)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - WAS

    private var wasView: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("\(uniqueStates.count)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("of 50 states")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            Section("Worked States") {
                ForEach(Array(uniqueStates).sorted(), id: \.self) { state in
                    Label(state, systemImage: "mappin.circle.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - County Hunter

    private var countyView: some View {
        List {
            Section {
                Text("County Hunter tracking requires integration with a county database.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }

            Section("Recent Counties") {
                Text("Log QSOs with state/county data to track this award.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Computed Stats

    private var workedCountries: [String] {
        // In a real app, DXCC entity is looked up per callsign prefix
        // For now, show unique callsign prefixes as countries
        Set(qsoStore.qsos.map { prefix($0.callsign) })
            .filter { $0 != "USA" }
            .map { _ in "Country \(Int.random(in: 1...50))" }
    }

    private var workedGrids: Set<String> {
        Set(qsoStore.qsos.compactMap { $0.grid?.prefix(4).uppercased() })
    }

    private var uniqueStates: [String] {
        // Placeholder — real app would geolocate from callsign
        []
    }

    private var progress: Double {
        min(Double(workedCountries.count) / 100.0, 1.0)
    }

    private var vuccProgress: Double {
        min(Double(workedGrids.count) / 100.0, 1.0)
    }

    private func prefix(_ callsign: String) -> String {
        let up = callsign.uppercased()
        if up.hasPrefix("K") || up.hasPrefix("N") || up.hasPrefix("W") || up.hasPrefix("AA-AL") {
            return "USA"
        }
        return String(up.prefix(2))
    }
}

#Preview {
    AwardsTabView()
        .environmentObject(QSOStore())
}
