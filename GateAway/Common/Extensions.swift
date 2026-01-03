import Foundation

// MARK: - Bundle Extension

extension Bundle {
  /// Returns the app's bundle identifier or a fallback
  static var identifier: String {
    return main.bundleIdentifier ?? "com.davian.GateAway"
  }
}
