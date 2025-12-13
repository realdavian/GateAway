import Foundation
import Combine

/// Legacy ViewModel - Use MonitoringStore.shared directly instead.
/// Kept for backward compatibility if needed.
final class MonitoringViewModel: ObservableObject {
    @Published var vpnStatistics: VPNStatistics = .empty
    private var cancellables = Set<AnyCancellable>()

    init() {
        MonitoringStore.shared.$vpnStatistics
            .receive(on: DispatchQueue.main)
            .assign(to: &$vpnStatistics)
    }
}
