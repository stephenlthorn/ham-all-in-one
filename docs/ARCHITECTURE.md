# ARCHITECTURE — HAM Signal

## Overview
SwiftUI-based amateur radio companion app. Data lives in ObservableObject stores. Network fetches are async/await.

## Stores
| Store | Responsibility |
|-------|---------------|
| RepeaterStore | ARD repeater database, offline JSON cache |
| SatelliteStore | SGP4 orbital predictions, next-pass calculation |
| QSOStore | Contact log (Callsign, frequency, mode, datetime) |
| CallsignService | FCC lookup + QRZ integration |
| AwardsTabView | WAS/DXCC/IOTA award progress tracking |
| APRSStore | APRS position tracking (stub, needs wiring) |
| DXClusterStore | DX Cluster spots (stub, needs wiring) |
| LoTWStore | Logbook of the World QSO matching (stub, needs wiring) |

## Data Flow
- Stores are @Observable (iOS 17) or ObservableObject
- Views read from stores via @Environment or @StateObject
- Network layer: URLSession async/await, no third-party deps
- Persistence: UserDefaults for preferences, JSON file for offline data

## Dependencies
- No external SPM packages currently
- XcodeGen for project generation
- fastlane for CI/CD

## Signing
- Team ID: TXHUY489RV
- Bundle ID: com.stephenthorn.HAMSignal
- Automatic signing in CI via app_store_connect_api_key
