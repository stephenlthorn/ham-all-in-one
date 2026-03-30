import SwiftUI

struct AwardsTabView: View {
    @EnvironmentObject var qsoStore: QSOStore
    @State private var selectedAward: AwardType = .dxcc

    enum AwardType: String, CaseIterable {
        case dxcc  = "DXCC"
        case vucc  = "VUCC"
        case was   = "WAS"
        case county = "Counties"
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

                switch selectedAward {
                case .dxcc:   dxccView
                case .vucc:   vuccView
                case .was:    wasView
                case .county: countyView
                }
            }
            .navigationTitle("Awards")
        }
    }

    // MARK: - DXCC

    private var dxccView: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: dxccProgress)
                            .stroke(dxccColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("\(workedEntities.count)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                            Text("of \(DXCCDatabase.shared.entities.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 130, height: 130)

                    Text("DXCC — \(dxccStatusText)")
                        .font(.headline)
                    Text("\(workedEntities.count) countries worked on \(bandsWorked) band\(bandsWorked == "1" ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if workedEntities.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No QSOs logged yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Log contacts to track your DXCC progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section("Worked Countries (\(workedEntities.count))") {
                    ForEach(workedEntities, id: \.country) { entity in
                        HStack {
                            Text(countryFlag(for: entity.country))
                            Text(entity.country)
                                .fontWeight(.medium)
                            Spacer()
                            Text("CQ \(entity.cqZone.map { String($0) } ?? "—") / ITU \(entity.ituZone.map { String($0) } ?? "—")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To earn DXCC:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Work 100 distinct countries on any amateur band.")
                            .font(.caption)
                        Text("Confirm via LoTW, QSL cards, or eQSL.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - VUCC (VHF Unified Grid Square Challenge)

    private var vuccView: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: vuccProgress)
                            .stroke(Color.purple, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("\(workedGrids.count)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                            Text("of 100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 130, height: 130)

                    Text("VUCC Progress")
                        .font(.headline)
                    Text("\(workedGrids.count) 4-character grid squares")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if workedGrids.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.3x3")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No grids logged yet")
                            .font(.subheadline)
                        Text("Log QSOs with Maidenhead grid squares to track VUCC")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section("Worked Grids (\(workedGrids.count))") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 6) {
                        ForEach(Array(workedGrids).sorted(), id: \.self) { grid in
                            Text(grid.uppercased())
                                .font(.caption.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - WAS (Worked All States)

    private var wasView: some View {
        let usStatesWorked = Array(workableUSStates)
        return List {
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: Double(usStatesWorked.count) / 50.0)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("\(usStatesWorked.count)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                            Text("of 50")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 130, height: 130)

                    Text(usStatesWorked.count == 50 ? "✅ WAS Complete!" : "WAS Progress")
                        .font(.headline)
                    Text("\(usStatesWorked.count) states worked")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("US States (\(usStatesWorked.count)/50)") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 6) {
                    ForEach(["AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA",
                             "HI","ID","IL","IN","IA","KS","KY","LA","ME","MD",
                             "MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ",
                             "NM","NY","NC","ND","OH","OK","OR","PA","RI","SC",
                             "SD","TN","TX","UT","VT","VA","WA","WV","WI","WY"], id: \.self) { state in
                        let worked = usStatesWorked.contains(state)
                        Text(state)
                            .font(.caption2.weight(.medium))
                            .frame(minWidth: 36)
                            .padding(.vertical, 5)
                            .background(worked ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            .foregroundColor(worked ? .blue : .secondary)
                            .cornerRadius(4)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - County Hunter

    private var countyView: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("County Hunter")
                        .font(.headline)
                    Text("Track US counties worked via callsign prefix → state → county.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            Section("Requirements") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Work 500 unique US counties for the CQ Counties award.")
                        .font(.subheadline)
                    Text("County is derived from the state portion of the callsign prefix.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("US County Map") {
                Text("County breakdown is derived from QSO state data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Data Helpers

    private var workedEntities: [DXCCEntity] {
        DXCCDatabase.shared.uniqueCountries(from: qsoStore.qsos)
    }

    private var workedGrids: Set<String> {
        Set(qsoStore.qsos.compactMap { qso -> String? in
            guard let grid = qso.grid, grid.count >= 4 else { return nil }
            return String(grid.prefix(4)).uppercased()
        })
    }

    /// US states derived from K/N/W/AA-AL callsign call areas.
    /// W1=CT, W2=NY/NJ, W3=PA/DE/DC/MD/VA/WV, W4=NC/SC/GA/FL/AL/TN/KY/IN/MI/OH,
    /// W5=AR/LA/MO/IA/MN/KS/NE/SD/ND/OK/TX,
    /// W6=CA/NV/AZ/HI/AK, W7=ID/MT/WY/UT/CO/NM/AZ,
    /// W8=WI/IL/MI/OH/KY/WV/VA/PA, W9=IN/IL/WI/MN/IA/MO/KS/NE/SD/ND/OK/TX,
    /// W0=KS/NE/SD/ND/MN/IA/MO/AR/LA/WI/IL
    private var workableUSStates: Set<String> {
        var states = Set<String>()
        for qso in qsoStore.qsos {
            let call = qso.callsign.uppercased()
            let prefix = USCallsignParser.callArea(for: call)
            states.formUnion(USCallsignParser.statesFor(callArea: prefix))
        }
        return states
    }

    private var dxccProgress: Double {
        min(Double(workedEntities.count) / 100.0, 1.0)
    }

    private var vuccProgress: Double {
        min(Double(workedGrids.count) / 100.0, 1.0)
    }

    private var dxccColor: Color {
        let count = workedEntities.count
        if count >= 100 { return .green }
        if count >= 75  { return .yellow }
        if count >= 50  { return .orange }
        return .red
    }

    private var dxccStatusText: String {
        let count = workedEntities.count
        if count >= 100 { return "✅ Confirmed!" }
        if count >= 75  { return "Almost there!" }
        if count >= 50  { return "Halfway!" }
        if count >= 25  { return "Getting started" }
        if count >= 10  { return "Building the list" }
        return "Keep logging!"
    }

    private var bandsWorked: String {
        let bands = Set(qsoStore.qsos.compactMap { qso -> String? in
            guard let freq = qso.frequency else { return nil }
            if freq.contains("28") || freq.contains("50") { return "10m" }
            if freq.contains("144") || freq.contains("146") { return "2m" }
            if freq.contains("420") || freq.contains("435") || freq.contains("440") { return "70cm" }
            return nil
        })
        return bands.isEmpty ? "1" : String(bands.count)
    }

    private func countryFlag(for country: String) -> String {
        let flags: [String: String] = [
            "United States": "🇺🇸", "Canada": "🇨🇦", "Mexico": "🇲🇽",
            "Argentina": "🇦🇷", "Brazil": "🇧🇷", "Colombia": "🇨🇴", "Peru": "🇵🇪", "Venezuela": "🇻🇪",
            "United Kingdom": "🇬🇧", "Germany": "🇩🇪", "France": "🇫🇷", "Italy": "🇮🇹", "Spain": "🇪🇸",
            "Netherlands": "🇳🇱", "Belgium": "🇧🇪", "Switzerland": "🇨🇭", "Austria": "🇦🇹", "Poland": "🇵🇱",
            "Czech Republic": "🇨🇿", "Hungary": "🇭🇺", "Romania": "🇷🇴", "Serbia": "🇷🇸",
            "Russia": "🇷🇺", "Ukraine": "🇺🇦", "Belarus": "🇧🇾", "Estonia": "🇪🇪", "Latvia": "🇱🇻", "Lithuania": "🇱🇹",
            "Japan": "🇯🇵", "South Korea": "🇰🇷", "China": "🇨🇳", "Taiwan": "🇹🇼", "Thailand": "🇹🇭",
            "Australia": "🇦🇺", "New Zealand": "🇳🇿", "Fiji": "🇫🇯", "Samoa": "🇼🇸",
            "South Africa": "🇿🇦", "Nigeria": "🇳🇬", "Kenya": "🇰🇪", "Egypt": "🇪🇬", "Morocco": "🇲🇦",
            "India": "🇮🇳", "Indonesia": "🇮🇩", "Malaysia": "🇲🇾", "Singapore": "🇸🇬", "Philippines": "🇵🇭",
            "Israel": "🇮🇱", "Turkey": "🇹🇷", "Saudi Arabia": "🇸🇦", "United Arab Emirates": "🇦🇪",
            "Cuba": "🇨🇺", "Jamaica": "🇯🇲", "Dominican Republic": "🇩🇴", "Haiti": "🇭🇹", "Puerto Rico": "🇵🇷",
            "Greece": "🇬🇷", "Portugal": "🇵🇹", "Ireland": "🇮🇪", "Iceland": "🇮🇸", "Norway": "🇳🇴",
            "Sweden": "🇸🇪", "Finland": "🇫🇮", "Denmark": "🇩🇰", "Greenland": "🇬🇱",
        ]
        return flags[country] ?? "🌍"
    }
}

// MARK: - US Callsign Call Area Parser

enum USCallsignParser {
    /// Extract US call area (0-9) from a US amateur callsign.
    /// Handles K, N, W, AA-AL prefixes.
    static func callArea(for callsign: String) -> Int? {
        let upper = callsign.uppercased()
        let prefix = String(upper.prefix(3))

        // AA-AL range
        if prefix.hasPrefix("AA") || prefix.hasPrefix("AB") || prefix.hasPrefix("AC") ||
           prefix.hasPrefix("AD") || prefix.hasPrefix("AE") || prefix.hasPrefix("AF") ||
           prefix.hasPrefix("AG") || prefix.hasPrefix("AH") || prefix.hasPrefix("AI") ||
           prefix.hasPrefix("AJ") || prefix.hasPrefix("AK") || prefix.hasPrefix("AL") {
            return Int(String(prefix.dropFirst(2)))
        }

        // K, N, W — call area is the 2nd character
        if upper.hasPrefix("K") || upper.hasPrefix("N") || upper.hasPrefix("W") {
            let second = String(upper.dropFirst(1)).prefix(1)
            return Int(second)
        }

        return nil
    }

    /// US states covered by each call area.
    static func statesFor(callArea: Int?) -> Set<String> {
        guard let area = callArea else { return [] }
        switch area {
        case 0: return ["AK", "HI"]  // 0 = Alaska, Hawaii (obsolete but still used)
        case 1: return ["CT", "ME", "MA", "NH", "RI", "VT"]
        case 2: return ["NY", "NJ"]
        case 3: return ["PA", "DE", "DC", "MD", "VA", "WV"]
        case 4: return ["NC", "SC", "GA", "FL", "AL", "TN", "KY", "IN", "MI", "OH"]
        case 5: return ["AR", "LA", "MS", "MO", "IA", "MN", "KS", "NE", "SD", "ND", "OK", "TX"]
        case 6: return ["CA", "NV", "AZ", "HI", "AK"]
        case 7: return ["ID", "MT", "WY", "UT", "CO", "NM", "AZ"]
        case 8: return ["WI", "IL", "MI", "OH", "KY", "WV", "VA", "PA"]
        case 9: return ["IN", "IL", "WI", "MN", "IA", "MO", "KS", "NE", "SD", "ND", "OK", "TX"]
        case 10: return ["KS", "NE", "SD", "ND", "MN", "IA", "MO", "AR", "LA", "WI", "IL"]
        default: return []
        }
    }
}

#Preview {
    AwardsTabView()
        .environmentObject(QSOStore())
}
