import Foundation

/// Defines the configuration requirements for an asynchronous polling operation
public protocol PollingConfigurating {
	/// The timeout for the polling operation in seconds.
	/// After this duration is exceeded, the polling will stop with a timeout error.
	var timeoutInterval: TimeInterval { get }

	/// Determines the interval between polling attempts.
	/// - Parameter iteration: The current iteration number of the polling operation (starts from 0)
	/// - Returns: The time interval in seconds to wait before the next polling attempt
	func pollingInterval(iteration: Int) -> TimeInterval
}

/// A simple implementation of PollingConfigurating that uses fixed intervals
public struct SimplePollingConfiguration: PollingConfigurating {
	/// The fixed time interval between polling attempts in seconds
	public let pollingInterval: TimeInterval
	/// The maximum duration for the entire polling operation in seconds
	public let timeoutInterval: TimeInterval

	/// Creates a new polling configuration with fixed intervals
	/// - Parameters:
	///   - pollingInterval: The time to wait between polling attempts in seconds
	///   - timeoutInterval: The maximum duration for the entire polling operation in seconds
	public init(pollingInterval: TimeInterval, timeoutInterval: TimeInterval) {
		self.pollingInterval = pollingInterval
		self.timeoutInterval = timeoutInterval
	}

	public func pollingInterval(iteration: Int) -> TimeInterval {
		pollingInterval
	}
}

/// An error that can be thrown by an ``AsyncPoller``
public enum PollingError: Error, Sendable {
	/// The polling timed out
	case timeout
	/// A new polling attempt started while running another polling job
	case alreadyPolling
}

public actor AsyncPoller<T: Sendable> {

	// MARK: - Injectables

	private let configuration: PollingConfigurating
	private let completionCondition: (T) -> Bool
	private let pollingJob: @Sendable () async throws -> T

	// MARK: - State
	public private(set) var isPolling = false
	public private(set) var iteration = 0

	/// Creates an instance of AsyncPoller<T>
	/// - Parameters:
	///   - configuration: the configuration of the poller, see ``PollingConfigurating``
	///   - completionCondition: The condition that will end the polling.
	///   - pollingJob: Async operation that will be executed every X seconds.
	public init(configuration: PollingConfigurating, completionCondition: @escaping (T) -> Bool, pollingJob: @Sendable @escaping () async throws -> T) {
		self.configuration = configuration
		self.completionCondition = completionCondition
		self.pollingJob = pollingJob
	}

	/// Starts the asynchronous polling process.
	///
	/// This method initiates a polling loop that repeatedly executes a specified asynchronous job
	/// until a completion condition is met, the polling times out, or the task is cancelled.
	///
	/// - Throws:
	///   - `PollingError.alreadyPolling`: If the polling process is already running when this method is called.
	///   - `PollingError.timeout`: If the total elapsed time exceeds the configured timeout interval.
	///   - `CancellationError`: If the polling task is explicitly cancelled.
	///
	/// - Returns:
	///   - The result of the asynchronous polling job, if the completion condition is met before timeout or cancellation.
	///
	/// ## Behavior:
	/// The method performs the following steps:
	/// 1. Validates that no other polling process is currently running. If one is, it throws `PollingError.alreadyPolling`.
	/// 2. Sets the polling state to active and initializes the iteration counter.
	/// 3. Uses a `ContinuousClock` to accurately measure the elapsed time since polling started.
	/// 4. Uses a `defer` block to ensure the polling state is properly reset when the method exits,
	///    regardless of whether it completes successfully, times out, or is cancelled.
	/// 5. Enters a polling loop that continues until one of the following conditions is met:
	///    - The asynchronous job completes and satisfies the completion condition.
	///    - The polling task is explicitly cancelled.
	///    - The configured timeout interval is exceeded.
	///
	/// ## Polling Loop:
	/// During each iteration:
	/// 1. Executes the asynchronous polling job and increments the iteration counter.
	/// 2. Evaluates the completion condition with the job result:
	///    - If the condition is met, returns the result and ends the polling process.
	/// 3. Calculates the total elapsed time using the `ContinuousClock`:
	///    - If the elapsed time exceeds the configured timeout interval, throws `PollingError.timeout`.
	///    - The goal is to not exceed the total timeout even with the last job running. Most real-world polling scenarios lean towards the "start before timeout" logic because it’s cleaner and easier to reason about - especially if you’re polling an external API and don’t want to make requests when the time window is over.
	/// 4. Determines the sleep interval for the next iteration using the configuration object.
	/// 5. Suspends the polling process for the calculated interval using `clock.sleep(for:)`.
	///
	/// ## Cancellation Handling:
	/// - The loop checks for task cancellation at the beginning of each iteration and throws
	///   a `CancellationError` if the polling process was cancelled.
	///
	/// ## Example Usage:
	/// ```swift
	/// let poller = AsyncPoller(configuration: config, completionCondition: { result in
	///     return result.isSuccessful
	/// }, pollingJob: {
	///     return await fetchData()
	/// })
	///
	/// do {
	///     let finalResult = try await poller.start()
	///     print("Polling succeeded with result: \(finalResult)")
	/// } catch {
	///     print("Polling failed with error: \(error)")
	/// }
	/// ```
	public func start() async throws -> T {
		guard !isPolling else {
			throw PollingError.alreadyPolling
		}

		isPolling = true
		iteration = 0
		let clock = ContinuousClock()
		let startInstant = clock.now

		defer {
			isPolling = false
		}

		while !Task.isCancelled {
			let result = try await pollingJob()
			iteration += 1

			if completionCondition(result) {
				return result
			}

			let duration = startInstant.duration(to: clock.now)
			let elapsed = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18

			if elapsed > configuration.timeoutInterval {
				throw PollingError.timeout
			}

			let nextInterval = configuration.pollingInterval(iteration: iteration)
			try await clock.sleep(for: .seconds(nextInterval))
		}
		throw CancellationError()
	}
}
