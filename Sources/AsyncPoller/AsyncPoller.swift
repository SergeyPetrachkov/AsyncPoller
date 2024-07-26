import Foundation

public final actor AsyncPoller<T: Sendable> {

    public struct Configuration {
        /// How frequently we need to execute the job. Interval in seconds.
        public let pollingInterval: TimeInterval
        /// The timeout for the polling. Interval in seconds.
        public let timeoutInterval: TimeInterval

        public init(pollingInterval: TimeInterval, timeoutInterval: TimeInterval) {
            self.pollingInterval = pollingInterval
            self.timeoutInterval = timeoutInterval
        }
    }

    public enum PollingError: Error {
        /// The polling timed out
        case timeout
        /// A new polling attempt started while running another polling job
        case alreadyPolling
    }

    // MARK: - Injectables

    /// The configuration of the poller.
    private let configuration: Configuration
    /// The condition that will end the polling.
    private let completionCondition: (T) -> Bool
    /// Async operation that will be executed every X seconds.
    private let pollingJob: @Sendable () async throws -> T

    // MARK: - State
    private var startTime: Date?
    private var isPolling = false

    public init(configuration: Configuration, completionCondition: @escaping (T) -> Bool, pollingJob: @Sendable @escaping () async throws -> T) {
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
            let result = try await pollingJob()

            if completionCondition(result) {
                return result
            }

            if let startTime = startTime, Date.now.timeIntervalSince(startTime) > configuration.timeoutInterval {
                throw PollingError.timeout
            }

            try await Task.sleep(nanoseconds: UInt64(configuration.pollingInterval * 1_000_000_000))
        }
        throw CancellationError()
    }
}
