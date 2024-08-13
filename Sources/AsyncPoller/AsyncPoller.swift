import Foundation

public protocol PollingConfigurating {
    /// The timeout for the polling. Interval in seconds.
    var timeoutInterval: TimeInterval { get }
    /// How frequently we need to execute the job. Interval in seconds.
    func pollingInterval(iteration: Int) -> TimeInterval
}

public struct SimplePollingConfiguration: PollingConfigurating {
    public let pollingInterval: TimeInterval
    public let timeoutInterval: TimeInterval

    public init(pollingInterval: TimeInterval, timeoutInterval: TimeInterval) {
        self.pollingInterval = pollingInterval
        self.timeoutInterval = timeoutInterval
    }

    public func pollingInterval(iteration: Int) -> TimeInterval {
        pollingInterval
    }
}

public enum PollingError: Error {
    /// The polling timed out
    case timeout
    /// A new polling attempt started while running another polling job
    case alreadyPolling
}

public final actor AsyncPoller<T: Sendable> {

    // MARK: - Injectables
    /// The configuration of the poller.
    private let configuration: PollingConfigurating
    /// The condition that will end the polling.
    private let completionCondition: (T) -> Bool
    /// Async operation that will be executed every X seconds.
    private let pollingJob: @Sendable () async throws -> T

    // MARK: - State
    public private(set) var startTime: Date?
    public private(set) var isPolling = false
    public private(set) var iteration = 0

    public init(configuration: PollingConfigurating, completionCondition: @escaping (T) -> Bool, pollingJob: @Sendable @escaping () async throws -> T) {
        self.configuration = configuration
        self.completionCondition = completionCondition
        self.pollingJob = pollingJob
    }

    /// Start the polling process.
    public func start() async throws -> T {
        guard !isPolling else {
            throw PollingError.alreadyPolling
        }

        isPolling = true
        startTime = Date.now

        defer { isPolling = false }

        while !Task.isCancelled {
            iteration += 1
            let result = try await pollingJob()

            if completionCondition(result) {
                return result
            }

            if let startTime = startTime, Date.now.timeIntervalSince(startTime) > configuration.timeoutInterval {
                throw PollingError.timeout
            }

            try await Task.sleep(nanoseconds: UInt64(configuration.pollingInterval(iteration: iteration) * 1_000_000_000))
        }
        throw CancellationError()
    }
}
