import Foundation
import SwiftUI

// MARK: - Localization Extension

/// String extension for easy localization
/// Supports basic strings, interpolation, and pluralization
extension String {

  // MARK: - Basic Localization

  /// Returns the localized version of the string
  /// Usage: "Connect to Server".localized
  var localized: String {
    NSLocalizedString(self, comment: "")
  }

  // MARK: - String Interpolation

  /// Returns the localized string with format arguments
  /// Usage: "Connected to %@".localized(with: serverName)
  func localized(with args: CVarArg...) -> String {
    String(format: self.localized, arguments: args)
  }

  // MARK: - Pluralization

  /// Returns the localized plural form based on count
  /// Requires entry in Localizable.stringsdict
  /// Usage: "servers_count".pluralized(count: 5) → "5 servers"
  func pluralized(count: Int) -> String {
    let format = NSLocalizedString(self, comment: "")
    return String.localizedStringWithFormat(format, count)
  }
}

// MARK: - SwiftUI Convenience

extension Text {
  /// Creates a localized Text view
  /// Usage: Text(localized: "Connect to Server")
  init(localized key: String) {
    self.init(key.localized)
  }

  /// Creates a localized Text view with format arguments
  /// Usage: Text(localized: "Connected to %@", serverName)
  init(localized key: String, _ args: CVarArg...) {
    self.init(String(format: key.localized, arguments: args))
  }
}
