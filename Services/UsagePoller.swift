import Foundation

actor UsagePoller {
    typealias PollAction = () async -> Bool

    private let normalInterval: TimeInterval
    private let activeInterval: TimeInterval
    private let backoffCeiling: TimeInterval
    private let pollAction: PollAction

    private var task: Task<Void, Never>?
    private var isActive = false
    private var consecutiveFailures = 0

    init(
        normalInterval: TimeInterval = 60,
        activeInterval: TimeInterval = 60,
        backoffCeiling: TimeInterval = 300,
        pollAction: @escaping PollAction
    ) {
        self.normalInterval = normalInterval
        self.activeInterval = activeInterval
        self.backoffCeiling = backoffCeiling
        self.pollAction = pollAction
    }

    func start() {
        guard task == nil else { return }

        task = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func setActive(_ active: Bool) {
        isActive = active
    }

    func refreshNow() async {
        await pollOnce()
    }

    func nextInterval() -> TimeInterval {
        let base = isActive ? activeInterval : normalInterval
        guard consecutiveFailures > 0 else {
            return base
        }

        let backoff = base * pow(2.0, Double(consecutiveFailures - 1))
        return min(backoff, backoffCeiling)
    }

    private func runLoop() async {
        while !Task.isCancelled {
            await pollOnce()
            let seconds = nextInterval()
            try? await Task.sleep(for: .seconds(seconds))
        }
    }

    private func pollOnce() async {
        let succeeded = await pollAction()
        if succeeded {
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
        }
    }
}
