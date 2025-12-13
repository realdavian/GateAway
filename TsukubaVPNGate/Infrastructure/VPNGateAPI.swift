import Foundation

// MARK: - Protocol (DIP: Depend on abstractions)

protocol VPNGateAPIProtocol {
    func fetchServers(completion: @escaping (Result<[VPNServer], Error>) -> Void)
}

// MARK: - Domain Model

struct VPNServer: Identifiable, Hashable {
    let id: String
    let hostName: String
    let ip: String
    let countryLong: String
    let countryShort: String
    let score: Int
    let pingMS: Int?
    let speedBps: Int?
    let openVPNConfigBase64: String
    
    var speedMbps: Int? {
        guard let bps = speedBps, bps > 0 else { return nil }
        return Int(Double(bps) / 1_000_000.0)
    }
}

// MARK: - Implementation (SRP: Single responsibility - fetch VPNGate server list)

final class VPNGateAPI: VPNGateAPIProtocol {
    private let endpoint = URL(string: "https://www.vpngate.net/api/iphone/")!
    
    func fetchServers(completion: @escaping (Result<[VPNServer], Error>) -> Void) {
        print("🌐 VPNGateAPI: Fetching from \(endpoint)")
        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                print("❌ VPNGateAPI: Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data else {
                print("❌ VPNGateAPI: No data received")
                let error = NSError(domain: "VPNGateAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                completion(.failure(error))
                return
            }
            
            print("📦 VPNGateAPI: Received \(data.count) bytes")
            
            guard let text = String(data: data, encoding: .utf8) else {
                print("❌ VPNGateAPI: Failed to decode as UTF-8")
                let error = NSError(domain: "VPNGateAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response encoding"])
                completion(.failure(error))
                return
            }
            
            do {
                let servers = try Self.parseCSV(text)
                print("✅ VPNGateAPI: Parsed \(servers.count) servers")
                completion(.success(servers))
            } catch {
                print("❌ VPNGateAPI: Parse error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Private CSV Parser
    
    private static func parseCSV(_ text: String) throws -> [VPNServer] {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        
        print("🔍 CSV Parser: Total lines: \(lines.count)")
        
        // VPNGate format:
        // Line 0: *vpn_servers (marker)
        // Line 1: #HostName,IP,Score,... (header with # prefix)
        // Line 2+: data rows
        // Last: * (footer)
        
        // Find header line (starts with # and contains column names)
        guard let headerIndex = lines.firstIndex(where: { $0.hasPrefix("#") && $0.contains(",") }) else {
            print("❌ CSV Parser: No header found!")
            return []
        }
        
        // Strip the # prefix from the header
        let headerLine = String(lines[headerIndex].dropFirst())
        print("🔍 CSV Parser: Header at line \(headerIndex): \(headerLine.prefix(100))...")
        
        let header = parseCSVLine(headerLine)
        print("🔍 CSV Parser: Parsed \(header.count) columns: \(header.prefix(10))")
        
        let columnIndex: [String: Int] = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })
        
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
        var parsedCount = 0
        
        for i in (headerIndex + 1)..<lines.count {
            let line = lines[i]
            if line.hasPrefix("#") { continue }
            if line.hasPrefix("*") { 
                print("🔍 CSV Parser: Found footer marker at line \(i)")
                break 
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            parsedCount += 1
            
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
                if skippedCount <= 3 {
                    print("⚠️ CSV Parser: Skipping row \(i) - host='\(host)', ip='\(ip)', ovpn.isEmpty=\(ovpn.isEmpty)")
                }
                continue
            }
            
            let id = "\(ip)|\(host)|\(countryShort)"
            result.append(VPNServer(
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
        
        print("🔍 CSV Parser: Parsed \(parsedCount) data lines, created \(result.count) servers, skipped \(skippedCount)")
        
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
                    // Escaped quote
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

