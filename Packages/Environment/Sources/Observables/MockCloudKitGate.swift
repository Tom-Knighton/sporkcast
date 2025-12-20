import Foundation
import Observation

public final class MockCloudKitGate: CloudKitGateProtocol, @unchecked Sendable {
    @ObservationIgnored
    public var didStartMonitoring: Bool = false

    @ObservationIgnored
    public var refreshCallCount: Int = 0

    public var state: CloudGate

    public init(state: CloudGate = .available) {
        self.state = state
    }

    public func startMonitoring() {
        didStartMonitoring = true
    }

    public func refresh() async {
        refreshCallCount += 1
    }
}
