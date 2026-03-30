import SwiftUI

@main
struct HAMAllInOneApp: App {
    @StateObject private var locationService = LocationService()
    @StateObject private var qsoStore = QSOStore()
    @StateObject private var repeaterStore = RepeaterStore()
    @StateObject private var satelliteStore = SatelliteStore()
    @StateObject private var aprsStore = APRSStore()
    @StateObject private var dxClusterStore = DXClusterStore()
    @StateObject private var lotwStore = LoTWStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationService)
                .environmentObject(qsoStore)
                .environmentObject(repeaterStore)
                .environmentObject(satelliteStore)
                .environmentObject(aprsStore)
                .environmentObject(dxClusterStore)
                .environmentObject(lotwStore)
        }
    }
}
