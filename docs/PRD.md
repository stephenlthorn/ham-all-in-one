# HAM Signal — Product Requirements Document

## Overview
HAM Signal (com.stephenthorn.HAMSignal) is an all-in-one iOS app for amateur radio operators. It aggregates repeater data, satellite passes, QSO logging, awards tracking, APRS, DX Cluster, and LoTW integration.

## Target Users
- Licensed amateur radio operators (US primarily, international as data allows)
- Hobbyists tracking awards (WAS, DXCC, IOTA)
- Field operators needing offline repeater data and satellite pass predictions

## Core Features

### Data Stores (implemented)
- **RepeaterStore** — ARD-sourced repeater database, offline cache
- **SatelliteStore** — satellite pass predictions
- **QSOStore** — contact logging
- **CallsignService** — FCC + QRZ callsign lookup
- **AwardsTabView** — WAS, DXCC, IOTA award tracking
- **APRSStore** — APRS tracking integration
- **DXClusterStore** — DX Cluster integration
- **LoTWStore** — Logbook of the World integration
- **SGP4** — satellite orbital prediction
- **ZDXCCDatabase** — DXCC entity database

### In Progress (A-004, A-005, A-006)
- APRSStore wiring to UI
- DXClusterStore wiring to UI
- LoTW integration completion

### Future Phases
- B: UI/UX polish, HIG compliance, VoiceOver, Dynamic Type
- C: App Store metadata, privacy policy, TestFlight external testers

## Tech Stack
- SwiftUI (primary UI framework)
- Swift 5.9+
- Xcode 15+
- XcodeGen for project generation
- fastlane for CI/CD

## Bundle ID
com.stephenthorn.HAMSignal

## App Store Connect ID
6760658659

## Data Repository
https://github.com/stephenlthorn/ham-radio-data (auto-syncs weekly from ARD)
