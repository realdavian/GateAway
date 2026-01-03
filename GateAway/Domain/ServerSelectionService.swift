import Foundation
import Network

// MARK: - Protocol

/// Server selection and filtering logic
protocol ServerSelectionServiceProtocol {
  /// Selects the best server using parallel ping tests
  /// - Parameter servers: Available servers to test
  /// - Returns: Fastest responding server, or nil if all fail
  func selectBestServerAsync(from servers: [VPNServer]) async -> VPNServer?

  /// Filters servers by country name
  /// - Parameters:
  ///   - servers: Servers to filter
  ///   - country: Country name to match
  func filterServers(_ servers: [VPNServer], byCountry country: String) -> [VPNServer]

  /// Returns top servers for a country, sorted by quality
  /// - Parameters:
  ///   - servers: All available servers
  ///   - country: Country to filter by
  ///   - limit: Maximum number of servers to return
  func topServers(from servers: [VPNServer], country: String, limit: Int) -> [VPNServer]

  /// Returns sorted list of unique country names
  func availableCountries(from servers: [VPNServer]) -> [String]
}

// MARK: - Implementation

/// Handles server selection using ping tests and score-based ranking
final class ServerSelectionService: ServerSelectionServiceProtocol {

  func selectBestServerAsync(from servers: [VPNServer]) async -> VPNServer? {
    guard !servers.isEmpty else { return nil }

    guard servers.count >= 5 else {
      Log.debug("Small list (\(servers.count)), using score-based selection")
      return servers.sorted { compareServers($0, $1) }.first
    }

    let candidates = Array(servers.sorted { compareServers($0, $1) }.prefix(10))

    Log.debug("Testing \(candidates.count) servers in parallel...")

    if let fastest = await testServersInParallel(candidates) {
      Log.success("Fastest server: \(fastest.countryLong) (\(fastest.ip))")
      return fastest
    }

    Log.warning("No ping responses, falling back to score-based selection")
    return servers.sorted { compareServers($0, $1) }.first
  }

  func filterServers(_ servers: [VPNServer], byCountry country: String) -> [VPNServer] {
    return servers.filter { $0.countryLong == country }
  }

  func topServers(from servers: [VPNServer], country: String, limit: Int) -> [VPNServer] {
    let filtered = filterServers(servers, byCountry: country)
    let sorted = filtered.sorted { compareServers($0, $1) }
    return Array(sorted.prefix(max(1, limit)))
  }

  func availableCountries(from servers: [VPNServer]) -> [String] {
    let countries = Set(servers.map { $0.countryLong }.filter { !$0.isEmpty })
    return countries.sorted()
  }

  // MARK: - Private

  private func testServersInParallel(_ candidates: [VPNServer]) async -> VPNServer? {
    await withTaskGroup(of: (VPNServer, TimeInterval?).self) { group in
      for server in candidates {
        group.addTask {
          let responseTime = await self.probeServer(server)
          return (server, responseTime)
        }
      }

      var best: (VPNServer, TimeInterval)?
      for await (server, time) in group {
        guard let time = time else { continue }

        if best == nil || time < best!.1 {
          best = (server, time)
          Log.debug("\(server.ip): \(String(format: "%.0fms", time * 1000))")
        }
      }

      return best?.0
    }
  }

  /// Tests server reachability via TCP connection on port 443
  private func probeServer(_ server: VPNServer) async -> TimeInterval? {
    let start = Date()
    let host = NWEndpoint.Host(server.ip)
    let port = NWEndpoint.Port(rawValue: 443) ?? .https

    let parameters = NWParameters.tcp
    parameters.allowLocalEndpointReuse = true

    let connection = NWConnection(host: host, port: port, using: parameters)

    return await withCheckedContinuation { continuation in
      var hasResumed = false

      connection.stateUpdateHandler = { [weak connection] state in
        guard !hasResumed else { return }

        switch state {
        case .ready:
          hasResumed = true
          let elapsed = Date().timeIntervalSince(start)
          continuation.resume(returning: elapsed)
          connection?.cancel()

        case .failed, .cancelled:
          hasResumed = true
          continuation.resume(returning: nil)
          connection?.cancel()

        default:
          break
        }
      }

      connection.start(queue: .global(qos: .userInitiated))

      Task {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        if !hasResumed {
          hasResumed = true
          continuation.resume(returning: nil)
          connection.cancel()
        }
      }
    }
  }

  /// Compares servers by ping time (lower is better), then by score (higher is better)
  private func compareServers(_ a: VPNServer, _ b: VPNServer) -> Bool {
    let aPing = a.pingMS ?? Int.max
    let bPing = b.pingMS ?? Int.max

    if aPing != bPing {
      return aPing < bPing
    }

    return a.score > b.score
  }
}
