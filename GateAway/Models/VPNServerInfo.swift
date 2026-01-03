import Foundation

/// Server information set when connecting
/// Contains static info about the connected server
struct VPNServerInfo: Equatable {
  let country: String?
  let countryShort: String?
  let serverName: String?
  let protocolType: String?
  let port: Int?
  let cipher: String?

  static let empty = VPNServerInfo(
    country: nil,
    countryShort: nil,
    serverName: nil,
    protocolType: nil,
    port: nil,
    cipher: nil
  )

  /// Create from VPNServer when connecting
  static func from(server: VPNServer) -> VPNServerInfo {
    VPNServerInfo(
      country: server.countryLong,
      countryShort: server.countryShort,
      serverName: server.hostName,
      protocolType: "OpenVPN",
      port: 1194,
      cipher: "AES-128-CBC"
    )
  }
}
