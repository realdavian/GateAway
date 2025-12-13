import XCTest
import Combine
@testable import TsukubaVPNGate

@MainActor
final class MonitoringStoreTests: XCTestCase {
    var store: MonitoringStore!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        store = MonitoringStore.shared
        cancellables = []
    }
    
    func testUpdateStatistics() {
        // Given
        let expectation = XCTestExpectation(description: "Store should publish updated statistics")
        let testStats = VPNStatistics(
            connectionState: .connected,
            connectedSince: Date(),
            vpnIP: "10.0.0.1",
            publicIP: "1.2.3.4",
            bytesReceived: 1024,
            bytesSent: 512,
            currentDownloadSpeed: 100.0,
            currentUploadSpeed: 50.0,
            ping: 20,
            protocolType: "UDP",
            port: 1194,
            cipher: "AES-128-CBC"
        )
        
        // When
        store.$vpnStatistics
            .dropFirst() // Drop initial value
            .sink { stats in
                // Then
                if stats.connectionState == .connected && stats.vpnIP == "10.0.0.1" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        store.updateStatistics(testStats)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testConnectionStateWait() {
        // Given
        let expectation = XCTestExpectation(description: "Store should publish connecting state")
        let connectingStats = VPNStatistics(connectionState: .connecting)
        
        // When
        store.$vpnStatistics
            .dropFirst()
            .sink { stats in
                if stats.connectionState == .connecting {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
            
        store.updateStatistics(connectingStats)
        
        wait(for: [expectation], timeout: 1.0)
    }
}
