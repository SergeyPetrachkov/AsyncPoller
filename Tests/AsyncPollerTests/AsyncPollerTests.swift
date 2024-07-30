import AsyncPoller
import Testing

@Suite("Async Poller Tests")
struct AsyncPollerTests {

    @Test("Happy Path")
    func happyPath() async throws {
        let configuration = AsyncPoller<String>.Configuration(
            pollingInterval: 0.0001,
            timeoutInterval: 1
        )
        let condition: (String) -> Bool = { $0 == "success" }
        let pollingJob: @Sendable () async -> String = {
            "success"
        }

        let poller = AsyncPoller(configuration: configuration, completionCondition: condition, pollingJob: pollingJob)

        try await confirmation { confirmed in
            let result = try await poller.start()
            #expect(result == "success")
            confirmed()
        }
    }

    @Test("Polling timeout")
    func timeout() async throws {
        let configuration = AsyncPoller<String>.Configuration(
            pollingInterval: 0.000001,
            timeoutInterval: 0.0001
        )
        let condition: (String) -> Bool = { $0 == "success" }
        let pollingJob: @Sendable () async -> String = {
            "not success"
        }

        let poller = AsyncPoller(configuration: configuration, completionCondition: condition, pollingJob: pollingJob)

        await #expect(throws: AsyncPoller<String>.PollingError.timeout) {
            let _ = try await poller.start()
        }
    }

    @Test("Already Polling")
    func alreadyPolling() async throws {
        await withKnownIssue(isIntermittent: true) {
            let configuration = AsyncPoller<String>.Configuration(
                pollingInterval: 0.01,
                timeoutInterval: 1
            )
            let condition: (String) -> Bool = { $0 == "success" }
            let pollingJob: @Sendable () async -> String = {
                "not success"
            }

            let poller = AsyncPoller(configuration: configuration, completionCondition: condition, pollingJob: pollingJob)

            Task {
                try await poller.start()
            }

            await #expect(throws: AsyncPoller<String>.PollingError.alreadyPolling) {
                try await poller.start()
            }
        }
    }
}
