import SwiftUI

struct DXClusterTabView: View {
    @EnvironmentObject var dxClusterStore: DXClusterStore
    @State private var myCallsign = UserDefaults.standard.string(forKey: "ham.myCallsign") ?? ""

    private let bands = ["All", "160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m", "6m", "2m"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection header
                connectionHeader

                // Band filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(bands, id: \.self) { band in
                            Button {
                                dxClusterStore.selectedBand = band
                            } label: {
                                Text(band)
                                    .font(.caption.weight(dxClusterStore.selectedBand == band ? .bold : .regular))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(dxClusterStore.selectedBand == band ? Color.orange : Color.gray.opacity(0.15))
                                    .foregroundColor(dxClusterStore.selectedBand == band ? .white : .primary)
                                    .cornerRadius(14)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
                .background(Color(UIColor.systemGroupedBackground))

                // Spot list
                List {
                    if dxClusterStore.filteredSpots.isEmpty {
                        ContentUnavailableView {
                            Label("No Spots", systemImage: "dot.radiowaves.left.and.right.slanted")
                        } description: {
                            if !dxClusterStore.isConnected {
                                Text("Connect to a DX cluster to see real-time spots")
                            } else {
                                Text("No spots match the current filter")
                            }
                        }
                    } else {
                        ForEach(dxClusterStore.filteredSpots) { spot in
                            DXSpotRow(spot: spot)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    // Re-fetch by reconnecting
                }
            }
            .navigationTitle("DX Cluster")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if dxClusterStore.isConnected {
                        Button {
                            dxClusterStore.disconnect()
                        } label: {
                            Label("Disconnect", systemImage: "wifi.slash")
                        }
                        .foregroundColor(.red)
                    } else {
                        Button {
                            Task {
                                let call = myCallsign.isEmpty ? "NOCALL" : myCallsign
                                await dxClusterStore.connect(myCallsign: call)
                            }
                        } label: {
                            Label("Connect", systemImage: "wifi")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var connectionHeader: some View {
        HStack {
            Circle()
                .fill(dxClusterStore.isConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(dxClusterStore.connectionState)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(dxClusterStore.spots.count) spots")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
}

// MARK: - DX Spot Row

struct DXSpotRow: View {
    let spot: DXClusterStore.DXSpot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // DX station callsign
                Text(spot.spottedCallsign)
                    .font(.headline.monospaced().bold())
                    .foregroundColor(.orange)

                Spacer()

                // Frequency
                Text(String(format: "%.1f kHz", spot.frequency))
                    .font(.subheadline.monospaced())
                    .foregroundColor(.primary)
            }

            HStack {
                // Spotter
                Label(spot.callsign, systemImage: "person.wave.2")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Age
                Text(spot.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let notes = spot.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                if let grid = spot.dxGrid {
                    Text(grid)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }

                Text(spot.source)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    DXClusterTabView()
        .environmentObject(DXClusterStore())
}
