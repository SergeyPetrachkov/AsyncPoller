import XCTest
@testable import AsyncPoller

// This is not a test really. Just a playground.

final class PollerTests: XCTestCase {
    func testExample() async throws {
		let configuration = AsyncPoller<Int>.Configuration(
			pollingInterval: 0.5,
			timeoutInterval: 20.0
		)

		let condition: (Int) -> Bool = { $0 == 10 }

		let pollingJob : @Sendable () async -> Int = {
			let randomNumber = Int.random(in: 1...200)
			try? await Task.sleep(nanoseconds: 1_000_000)
			print("Generated random number: \(randomNumber)")
			return randomNumber
		}

        let poller = AsyncPoller<Int>(configuration: configuration, completionCondition: condition, pollingJob: pollingJob)

		let pollingExpectation = expectation(description: "Polling result")
		let task = Task {
			defer {
				pollingExpectation.fulfill()
			}
			let result = try await poller.start()
			XCTAssertEqual(result, 10)
		}
		print("Will sleep before cancelling the task")
		try await Task.sleep(nanoseconds: 10 * 1_000_000_000)
		print("Will cancel the task")
		task.cancel()

		await fulfillment(of: [pollingExpectation])
		XCTAssertTrue(task.isCancelled)
    }
}
