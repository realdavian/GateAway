import Foundation

/// Real-time VPN statistics published by VPNMonitor
/// Contains only data that changes during an active connection
struct VPNStats: Equatable {
  let bytesReceived: Int64
  let bytesSent: Int64
  let downloadSpeed: Double  // bytes per second
  let uploadSpeed: Double  // bytes per second
  let vpnIP: String?
  let connectedSince: Date?

  static let empty = VPNStats(
    bytesReceived: 0,
    bytesSent: 0,
    downloadSpeed: 0,
    uploadSpeed: 0,
    vpnIP: nil,
    connectedSince: nil
  )
}

// MARK: - Formatting Extensions

extension VPNStats {
  var formattedBytesReceived: String {
    ByteCountFormatter.string(fromByteCount: bytesReceived, countStyle: .binary)
  }

  var formattedBytesSent: String {
    ByteCountFormatter.string(fromByteCount: bytesSent, countStyle: .binary)
  }

  var formattedDownloadSpeed: String {
    ByteCountFormatter.string(fromByteCount: Int64(downloadSpeed), countStyle: .binary) + "/s"
  }

  var formattedUploadSpeed: String {
    ByteCountFormatter.string(fromByteCount: Int64(uploadSpeed), countStyle: .binary) + "/s"
  }
}
