import Foundation

// MARK: - Blacklisted Server Model

struct BlacklistedServer: Codable, Identifiable {
    let id: String // Server IP
    let hostname: String
    let country: String
    let countryShort: String // Two-letter country code for flag emoji
    let reason: String
    let blacklistedAt: Date
    let expiresAt: Date?
    
    // Custom init to handle migration from old data without countryShort
    init(id: String, hostname: String, country: String, countryShort: String, reason: String, blacklistedAt: Date, expiresAt: Date?) {
        self.id = id
        self.hostname = hostname
        self.country = country
        self.countryShort = countryShort
        self.reason = reason
        self.blacklistedAt = blacklistedAt
        self.expiresAt = expiresAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        hostname = try container.decode(String.self, forKey: .hostname)
        country = try container.decode(String.self, forKey: .country)
        // Fallback for legacy data without countryShort
        countryShort = try container.decodeIfPresent(String.self, forKey: .countryShort) ?? String(country.prefix(2)).uppercased()
        reason = try container.decode(String.self, forKey: .reason)
        blacklistedAt = try container.decode(Date.self, forKey: .blacklistedAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
    }
    
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
        ("2 Hours", .duration(7200)),
        ("8 Hours", .duration(28800)),
        ("1 Day", .duration(86400)),
        ("7 Days", .duration(604800)),
        ("Permanent", .never)
    ]
}

