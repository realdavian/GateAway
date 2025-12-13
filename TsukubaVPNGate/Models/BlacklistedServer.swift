import Foundation

// MARK: - Blacklisted Server Model

struct BlacklistedServer: Codable, Identifiable {
    let id: String // Server IP
    let hostname: String
    let country: String
    let reason: String
    let blacklistedAt: Date
    let expiresAt: Date?
    
    var isExpired: Bool {
        guard let expiry = expiresAt else { return false }
        return Date() > expiry
    }
    
    var expiryDescription: String {
        guard let expiry = expiresAt else { return "Never" }
        
        if isExpired {
            return "Expired"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Expires " + formatter.localizedString(for: expiry, relativeTo: Date())
    }
    
    var formattedBlacklistDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: blacklistedAt)
    }
}

// MARK: - Blacklist Expiry Options

enum BlacklistExpiry: Codable {
    case never
    case duration(TimeInterval)
    case date(Date)
    
    var displayName: String {
        switch self {
        case .never:
            return "Permanent"
        case .duration(let seconds):
            if seconds < 3600 {
                return "\(Int(seconds / 60)) minutes"
            } else if seconds < 86400 {
                return "\(Int(seconds / 3600)) hours"
            } else {
                return "\(Int(seconds / 86400)) days"
            }
        case .date(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    func expiryDate(from: Date) -> Date? {
        switch self {
        case .never:
            return nil
        case .duration(let seconds):
            return from.addingTimeInterval(seconds)
        case .date(let date):
            return date
        }
    }
    
    static let presets: [(String, BlacklistExpiry)] = [
        ("1 Hour", .duration(3600)),
        ("6 Hours", .duration(21600)),
        ("1 Day", .duration(86400)),
        ("1 Week", .duration(604800)),
        ("Permanent", .never)
    ]
}

