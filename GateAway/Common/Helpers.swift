import Foundation

// MARK: - Helper Functions

/// Convert country code to flag emoji
/// - Parameter countryCode: Two-letter country code (e.g., "JP", "US")
/// - Returns: Flag emoji or globe if invalid
func flagEmoji(for countryCode: String) -> String {
  // Unicode Regional Indicator Symbol base (0x1F1E5) - adding country code chars gives flag emoji
  let base: UInt32 = 127397
  var emoji = ""
  for scalar in countryCode.uppercased().unicodeScalars {
    if let scalarValue = UnicodeScalar(base + scalar.value) {
      emoji.unicodeScalars.append(scalarValue)
    }
  }
  return emoji.isEmpty ? "🌍" : emoji
}

/// Format speed from bits per second to human-readable Mbps
/// - Parameter bps: Speed in bits per second
/// - Returns: Formatted string with one decimal place
func formatSpeed(_ bps: Int) -> String {
  let mbps = Double(bps) / 1_000_000
  return String(format: "%.1f", mbps)
}
