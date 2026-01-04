import Foundation

// MARK: - Protocol

/// Fetches VPN server list from VPNGate API
protocol VPNGateAPIProtocol {
  /// Fetches all available VPN servers
  /// - Returns: Array of VPN servers parsed from API
  /// - Throws: Network or parsing errors
  func fetchServers() async throws -> [VPNServer]
}

// MARK: - Domain Model

/// Represents a VPN server from VPNGate
struct VPNServer: Identifiable, Hashable, Codable {
  let id: String
  let hostName: String
  let ip: String
  let countryLong: String
  let countryShort: String
  let score: Int
  let pingMS: Int?
  let speedBps: Int?
  let openVPNConfigBase64: String

  /// Speed in Mbps, nil if unavailable
  var speedMbps: Int? {
    guard let bps = speedBps, bps > 0 else { return nil }
    return Int(Double(bps) / 1_000_000.0)
  }
}

// MARK: - Network Session Protocol

protocol NetworkSessionProtocol {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSessionProtocol {}

// MARK: - Implementation

final class VPNGateAPI: VPNGateAPIProtocol {
  private let endpoint = URL(string: Constants.Paths.vpngate)!
  private let session: NetworkSessionProtocol

  init(session: NetworkSessionProtocol) {
    self.session = session
  }

  func fetchServers() async throws -> [VPNServer] {
    Log.info("Fetching from \(endpoint)")

    var request = URLRequest(url: endpoint)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = Constants.Timeouts.apiRequest

    let (data, _) = try await session.data(for: request)
    Log.debug("Received \(data.count) bytes")

    guard let text = String(data: data, encoding: .utf8) else {
      throw NSError(
        domain: "VPNGateAPI", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid response encoding"])
    }

    let servers = try Self.parseCSV(text)
    Log.success("Parsed \(servers.count) servers")
    return servers
  }

  // MARK: - CSV Parser

  private static func parseCSV(_ text: String) throws -> [VPNServer] {
    let lines =
      text
      .split(whereSeparator: \.isNewline)
      .map(String.init)

    Log.debug("CSV Parser: Total lines: \(lines.count)")

    guard let headerIndex = lines.firstIndex(where: { $0.hasPrefix("#") && $0.contains(",") })
    else {
      Log.error("CSV Parser: No header found!")
      return []
    }

    let headerLine = String(lines[headerIndex].dropFirst())
    let header = parseCSVLine(headerLine)

    let columnIndex: [String: Int] = Dictionary(
      uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })

    func get(_ row: [String], _ name: String) -> String {
      guard let idx = columnIndex[name], idx < row.count else { return "" }
      return row[idx]
    }

    func getInt(_ row: [String], _ name: String) -> Int? {
      let value = get(row, name)
      return Int(value)
    }

    var result: [VPNServer] = []
    var skippedCount = 0

    for i in (headerIndex + 1)..<lines.count {
      let line = lines[i]
      if line.hasPrefix("#") { continue }
      if line.hasPrefix("*") { break }
      if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

      let row = parseCSVLine(line)
      let host = get(row, "HostName")
      let ip = get(row, "IP")
      let countryLong = get(row, "CountryLong")
      let countryShort = get(row, "CountryShort")
      let score = getInt(row, "Score") ?? 0
      let ping = getInt(row, "Ping")
      let speed = getInt(row, "Speed")
      let ovpn = get(row, "OpenVPN_ConfigData_Base64")

      if host.isEmpty || ip.isEmpty || ovpn.isEmpty {
        skippedCount += 1
        continue
      }

      let id = "\(ip)|\(host)|\(countryShort)"
      result.append(
        VPNServer(
          id: id,
          hostName: host,
          ip: ip,
          countryLong: countryLong,
          countryShort: countryShort,
          score: score,
          pingMS: ping,
          speedBps: speed,
          openVPNConfigBase64: ovpn
        ))
    }

    Log.debug("CSV Parser: Created \(result.count) servers, skipped \(skippedCount)")

    return result
  }

  private static func parseCSVLine(_ line: String) -> [String] {
    var output: [String] = []
    var current = ""
    var inQuotes = false
    var i = line.startIndex

    while i < line.endIndex {
      let ch = line[i]

      if ch == "\"" {
        let next = line.index(after: i)
        if inQuotes, next < line.endIndex, line[next] == "\"" {
          current.append("\"")
          i = line.index(after: next)
          continue
        } else {
          inQuotes.toggle()
          i = next
          continue
        }
      }

      if ch == "," && !inQuotes {
        output.append(current)
        current = ""
        i = line.index(after: i)
        continue
      }

      current.append(ch)
      i = line.index(after: i)
    }

    output.append(current)
    return output
  }
}
