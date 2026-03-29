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

            AwardsTabView()
                .tabItem {
                    Label("Awards", systemImage: "trophy")
                }
                .tag(3)

            ProfileTabView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(4)
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
}
