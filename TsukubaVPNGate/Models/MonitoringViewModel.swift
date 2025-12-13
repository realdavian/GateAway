import Foundation
import Combine

final class MonitoringViewModel: ObservableObject {
    @Published var vpnStatistics: VPNStatistics = .empty

    private let monitor: VPNMonitor
    private var cancellables = Set<AnyCancellable>()

    init(monitor: VPNMonitor = .shared) {
        self.monitor = monitor

        monitor.statisticsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.vpnStatistics = stats
                print("📊 [MonitoringViewModel] Received stats: \(stats)")
            }
            .store(in: &cancellables)

        monitor.startMonitoring()
    }

    deinit {
        print("❌ MonitoringViewModel deinit")
        monitor.stopMonitoring()
    }
}
