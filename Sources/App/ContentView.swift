import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LogTabView()
                .tabItem {
                    Label("Log", systemImage: "pencil.line")
                }
                .tag(0)

            RepeatersTabView()
                .tabItem {
                    Label("Repeaters", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(1)

            SatellitesTabView()
                .tabItem {
                    Label("Satellites", systemImage: "sparkles")
                }
                .tag(2)

            APRSTabView()
                .tabItem {
                    Label("APRS", systemImage: "map")
                }
                .tag(3)

            DXClusterTabView()
                .tabItem {
                    Label("DX", systemImage: "dot.radiowaves.left.and.right.slanted")
                }
                .tag(4)

            AwardsTabView()
                .tabItem {
                    Label("Awards", systemImage: "trophy")
                }
                .tag(5)

            LoTWTabView()
                .tabItem {
                    Label("LoTW", systemImage: "checkmark.seal")
                }
                .tag(6)

            ProfileTabView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(7)
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationService())
        .environmentObject(QSOStore())
        .environmentObject(RepeaterStore())
        .environmentObject(SatelliteStore())
        .environmentObject(APRSStore())
        .environmentObject(DXClusterStore())
        .environmentObject(LoTWStore())
}
