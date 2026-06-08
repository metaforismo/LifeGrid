import Foundation
import Observation

@MainActor
@Observable
final class CurrentDateTicker {
    var now: Date = .now
    @ObservationIgnored private var task: Task<Void, Never>?

    init() {
        task = Task { @MainActor in
            while !Task.isCancelled {
                now = .now
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    deinit {
        task?.cancel()
    }
}
