import SwiftUI
import MapKit

struct RepeatersTabView: View {
    @EnvironmentObject var repeaterStore: RepeaterStore
    @EnvironmentObject var locationService: LocationService
    @State private var viewMode: ViewMode = .list
    @State private var scanRangeMiles: Double = 25

    enum ViewMode { case list, radar, map }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker
                Picker("View", selection: $viewMode) {
                    Label("List", systemImage: "list.bullet").tag(ViewMode.list)
                    Label("Radar", systemImage: "antenna.radiowaves.left.and.right").tag(ViewMode.radar)
                    Label("Map", systemImage: "map").tag(ViewMode.map)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                Group {
                    switch viewMode {
                    case .list:   listView
                    case .radar:  radarView
                    case .map:    mapView
                    }
                }
            }
            .navigationTitle("Repeaters")
            .searchable(text: $repeaterStore.searchQuery, prompt: "Search callsign, city, frequency...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Section("Band") {
                            Button("All Bands") { repeaterStore.selectedBand = nil }
                            ForEach(RepeaterBand.allCases, id: \.self) { band in
                                Button(band.rawValue) { repeaterStore.selectedBand = band }
                            }
                        }
                        Section("Sort") {
                            Button("By Distance") { repeaterStore.sortOrder = .distance }
                            Button("By Frequency") { repeaterStore.sortOrder = .frequency }
                            Button("By Callsign") { repeaterStore.sortOrder = .callsign }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            if let loc = locationService.currentLocation {
                Section {
                    Text("\(Int(scanRangeMiles)) mi range")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                ForEach(filteredRepeaters) { repeater in
                    RepeaterRow(repeater: repeater)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Radar View

    private var radarView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) - 40
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2

            ZStack {
                // Background
                Color.black

                // Compass ring
                ForEach(Array(0..<360), id: \.self) { deg in
                    if deg % 30 == 0 {
                        let rad = Double(deg - 90).degreesToRadians
                        VStack(spacing: 0) {
                            Text(directionLabel(deg))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 1, height: deg % 90 == 0 ? 12 : 6)
                        }
                        .position(
                            x: center.x + cos(rad) * (radius - 16),
                            y: center.y + sin(rad) * (radius - 16)
                        )
                    }
                }

                // Range rings
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        .frame(width: size * fraction, height: size * fraction)
                        .position(center)
                }

                // Sweep animation
                RadarSweepView()
                    .frame(width: size, height: size)
                    .position(center)

                // Repeater dots
                ForEach(filteredRepeaters.prefix(20)) { repeater in
                    if let dist = repeater.distanceMiles,
                       let bear = repeater.bearing,
                       dist <= Double(scanRangeMiles) {
                        let rad = Double(bear - 90).degreesToRadians
                        let scaledDist = dist / Double(scanRangeMiles)
                        let dotX = center.x + cos(rad) * (radius * scaledDist)
                        let dotY = center.y + sin(rad) * (radius * scaledDist)
                        Circle()
                            .fill(dotColor(for: repeater))
                            .frame(width: 8, height: 8)
                            .position(x: dotX, y: dotY)
                            .onTapGesture {
                                // Show detail
                            }
                    }
                }

                // Center: user location
                Circle()
                    .fill(Color.orange)
                    .frame(width: 10, height: 10)
                    .position(center)

                // Labels
                VStack {
                    HStack {
                        Text("N").font(.caption.bold()).foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    Spacer()
                }
                .frame(height: size)
                .position(x: center.x, y: center.y - radius + 20)

                // Scan range slider
                VStack {
                    Spacer()
                    HStack {
                        Text("5 mi")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        Slider(value: $scanRangeMiles, in: 5...100, step: 5)
                            .tint(.orange)
                        Text("100 mi")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal)
                    Text("\(filteredRepeaters.count) repeaters in range")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 20)
            }
        }
    }

    private func dotColor(for repeater: Repeater) -> Color {
        if let online = repeater.isOnline, !online { return .red }
        return .green
    }

    private func directionLabel(_ deg: Int) -> String {
        switch deg {
        case 0: return "N"
        case 90: return "E"
        case 180: return "S"
        case 270: return "W"
        default: return ""
        }
    }

    // MARK: - Map View

    private var mapView: some View {
        Map {
            // User location
            if let loc = locationService.currentLocation {
                Annotation("You", coordinate: loc.coordinate) {
                    Circle().fill(.orange).frame(width: 12, height: 12)
                }
            }

            // Repeaters
            ForEach(filteredRepeaters) { repeater in
                Annotation(repeater.callsign, coordinate: repeater.location) {
                    VStack(spacing: 2) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                        Text(repeater.callsign)
                            .font(.caption2)
                            .padding(2)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .mapStyle(.standard)
    }

    private var filteredRepeaters: [Repeater] {
        repeaterStore.filtered(userLocation: locationService.currentLocation)
    }
}

// MARK: - Radar Sweep Animation

struct RadarSweepView: View {
    @State private var angle: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2
                let currentAngle = angle

                var path = Path()
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(currentAngle - 5),
                    endAngle: .degrees(currentAngle),
                    clockwise: true
                )
                path.closeSubpath()

                let gradient = Gradient(colors: [
                    Color.green.opacity(0.5),
                    Color.green.opacity(0.0)
                ])
                context.fill(
                    path,
                    with: .linearGradient(
                        gradient,
                        startPoint: center,
                        endPoint: CGPoint(
                            x: center.x + cos(currentAngle.degreesToRadians) * radius,
                            y: center.y + sin(currentAngle.degreesToRadians) * radius
                        )
                    )
                )
            }
            .onChange(of: timeline.date) { _, _ in
                angle += 2
                if angle >= 360 { angle = 0 }
            }
        }
    }
}

// MARK: - Repeater Row

struct RepeaterRow: View {
    let repeater: Repeater

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(repeater.callsign)
                    .font(.headline.monospaced())
                Spacer()
                if let dist = repeater.distanceMiles {
                    Text("\(Int(dist)) mi")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                if let bear = repeater.bearing {
                    Text(bearingLabel(bear))
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                Text(repeater.frequency)
                    .font(.subheadline.monospaced())
                    .fontWeight(.semibold)

                if let offset = repeater.offset {
                    Text(offset)
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                if let tone = repeater.tone {
                    Text("CTCSS \(tone)")
                        .font(.caption)
                        .foregroundColor(.purple)
                }

                if let mode = repeater.mode {
                    Text(mode)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            if let city = repeater.city, let state = repeater.state {
                Text("\(city), \(state)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func bearingLabel(_ bearing: Double) -> String {
        let dirs = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
        let index = Int((bearing + 11.25) / 22.5) % 16
        return "\(dirs[index]) \(Int(bearing))°"
    }
}

#Preview {
    RepeatersTabView()
        .environmentObject(RepeaterStore())
        .environmentObject(LocationService())
}
