# TsukubaVPNGate Architecture

## Overview
This project follows **SOLID principles** with a clean **layered architecture** that separates concerns and allows easy testing and future modifications.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  (AppDelegate, StatusBarController, SettingsView)           │
│  - UI logic only                                             │
│  - Depends on Domain via protocols                           │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  (AppCoordinator, Services, Repositories)                   │
│  - Business logic                                            │
│  - Protocol definitions (abstractions)                       │
│  - No UI, no implementation details                          │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                        │
│  (VPNGateAPI, TunnelblickVPNController)                     │
│  - External integrations                                     │
│  - Implements Domain protocols                               │
└─────────────────────────────────────────────────────────────┘
```

## SOLID Principles Applied

### 1. Single Responsibility Principle (SRP)
Each class has **one reason to change**:

- **`ServerRepository`**: Manages server data persistence and caching
- **`ServerSelectionService`**: Implements server selection/filtering logic
- **`VPNConnectionManager`**: Manages VPN connection lifecycle
- **`PreferencesManager`**: Handles user preferences persistence
- **`AppCoordinator`**: Coordinates services (orchestration only)
- **`StatusBarController`**: Handles menu bar UI
- **`VPNGateAPI`**: Fetches server list from VPNGate
- **`TunnelblickVPNController`**: Integrates with Tunnelblick

### 2. Open/Closed Principle (OCP)
- All services are **open for extension** via protocols
- **Closed for modification**: Adding a new VPN backend (e.g., NetworkExtension) doesn't require changing existing code—just implement `VPNControlling`

### 3. Liskov Substitution Principle (LSP)
- Any implementation of `VPNControlling` can replace `TunnelblickVPNController` without breaking the app
- Any implementation of `ServerRepositoryProtocol` can replace `ServerRepository`

### 4. Interface Segregation Principle (ISP)
- Protocols are **focused and minimal**:
  - `VPNControlling`: Only connect/disconnect
  - `ServerRepositoryProtocol`: Only server data operations
  - `ServerSelectionServiceProtocol`: Only selection logic
  - `PreferencesManagerProtocol`: Only preferences operations

### 5. Dependency Inversion Principle (DIP)
- **High-level modules** (Domain) don't depend on **low-level modules** (Infrastructure)
- Both depend on **abstractions** (protocols)
- Dependency injection in `AppDelegate`:

```swift
let vpnController: VPNControlling = TunnelblickVPNController()
let connectionManager: VPNConnectionManagerProtocol = VPNConnectionManager(controller: vpnController)
let coordinator = AppCoordinator(
    serverRepository: serverRepository,
    selectionService: selectionService,
    connectionManager: connectionManager,
    preferencesManager: preferencesManager
)
```

## Directory Structure

```
TsukubaVPNGate/
├── Domain/                          # Business logic (no dependencies)
│   ├── AppCoordinator.swift         # Orchestrates services
│   ├── ServerRepository.swift       # Server data management
│   ├── ServerSelectionService.swift # Selection/filtering logic
│   ├── VPNConnectionManager.swift   # VPN lifecycle management
│   └── PreferencesManager.swift     # User preferences
│
├── Infrastructure/                  # External integrations
│   ├── VPNGateAPI.swift            # VPNGate API client
│   ├── VPNControlling.swift        # VPN abstraction protocol
│   └── TunnelblickVPNController.swift # Tunnelblick implementation
│
├── Presentation/                    # UI layer
│   ├── AppDelegate.swift           # App entry + DI container
│   ├── StatusBarController.swift   # Menu bar UI
│   ├── SettingsView.swift          # Settings UI (SwiftUI)
│   └── SettingsWindowController.swift
│
└── main.swift                       # App entry point
```

## Key Design Decisions

### 1. Protocol-Oriented Design
All dependencies are injected as **protocols**, not concrete types. This enables:
- Easy unit testing (mock implementations)
- Swapping implementations without code changes
- Clear contracts between layers

### 2. Coordinator Pattern
`AppCoordinator` orchestrates all services and provides a **single entry point** for the presentation layer. This:
- Keeps UI controllers thin
- Centralizes business logic
- Makes testing easier

### 3. Separation of Concerns
- **Presentation** layer handles UI only (no business logic)
- **Domain** layer contains all business rules (no UI, no external dependencies)
- **Infrastructure** layer handles external integrations (VPNGate API, Tunnelblick)

### 4. Async/Await Ready
All service methods use completion handlers, making it easy to migrate to Swift Concurrency (async/await) in the future.

## Testing Strategy

### Unit Tests (Future)
- Mock `VPNControlling` to test `VPNConnectionManager`
- Mock `VPNGateAPIProtocol` to test `ServerRepository`
- Test `ServerSelectionService` logic in isolation
- Test `PreferencesManager` with in-memory `UserDefaults`

### Integration Tests (Future)
- Test `AppCoordinator` with real services
- Test full connect/disconnect flow

## Future Enhancements

### Easy to Add (Thanks to SOLID)
1. **NetworkExtension VPN Backend**: Implement `VPNControlling` with `NEPacketTunnelProvider`
2. **Server Favorites**: Add to `ServerRepository`
3. **Auto-Reconnect**: Add `ReconnectPolicy` service
4. **Latency Measurement**: Add `LatencyService` implementing ping/TCP connect timing
5. **Analytics**: Add `AnalyticsService` protocol + implementation

### Migration Path
To swap Tunnelblick for NetworkExtension:
1. Create `NetworkExtensionVPNController: VPNControlling`
2. Change one line in `AppDelegate`:
   ```swift
   let vpnController: VPNControlling = NetworkExtensionVPNController()
   ```
3. Done! No other code changes needed.

## Dependencies

- **macOS 11.0+**: Minimum deployment target
- **Tunnelblick**: Required for VPN connections (MVP)
- **No third-party frameworks**: Pure Swift + AppKit + SwiftUI

## Build & Run

1. Open `TsukubaVPNGate.xcodeproj` in Xcode
2. Build & Run (`⌘R`)
3. In **System Settings → Control Center**, set **TsukubaVPNGate** to "Always Show in Menu Bar"
4. Look for the menu bar icon (🔒 VPN in Debug, shield icon in Release)

## Milestones Completed

- ✅ **Milestone 1**: Menu bar app + server list + settings
- ✅ **Milestone 2**: Tunnelblick integration + SOLID refactor
- ⏳ **Milestone 3**: Auto-reconnect + health monitoring (future)

