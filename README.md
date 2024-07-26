# AsyncPoller
AsyncPoller is a Swift package that provides a simple, actor-based utility for performing asynchronous polling operations. It allows you to periodically execute a task until a certain condition is met or a timeout occurs.

## Features
* Configurable polling interval and timeout.
* Asynchronous and thread-safe execution using Swift's concurrency model.
* Customizable completion condition to determine when the polling should stop.

## Installation
### Swift Package Manager
You can add AsyncPoller to your project using Swift Package Manager. In your Package.swift file, add the following dependency:
```Swift
dependencies: [
    .package(url: "https://github.com/SergeyPetrachkov/AsyncPoller.git", from: "1.0.0")
]

```
Then, include "AsyncPoller" as a dependency in your target:
```Swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AsyncPoller"]
    )
]

```

## Usage
To use AsyncPoller, first import the module:
```
import AsyncPoller
```

### Creating a Poller
Create a new instance of AsyncPoller by providing a configuration, a completion condition, and a polling job.

```Swift
let poller = AsyncPoller<String>(
    configuration: .init(pollingInterval: 5, timeoutInterval: 60),
    completionCondition: { result in
        return result == "success"
    },
    pollingJob: {
        // Your async job that returns a result of type T (e.g., String in this case)
        return await fetchStatusFromServer()
    }
)
```

### Starting the Poller
Start the polling process by calling the start() method. This method will run your polling job at the specified interval until the completion condition is met or the timeout occurs.

```Swift
Task {
    do {
        let result = try await poller.start()
        print("Polling succeeded with result: \(result)")
    } catch {
        print("Polling failed with error: \(error)")
    }
}
```

### Configuration
`AsyncPoller` is configured using the `Configuration` struct, which specifies the polling interval and the timeout interval.

```Swift
public struct Configuration {
    public let pollingInterval: TimeInterval
    public let timeoutInterval: TimeInterval

    public init(pollingInterval: TimeInterval, timeoutInterval: TimeInterval) {
        self.pollingInterval = pollingInterval
        self.timeoutInterval = timeoutInterval
    }
}
```

### Errors
AsyncPoller can throw the following errors:

`PollingError.timeout`: Thrown when the polling operation exceeds the specified timeout interval.
`PollingError.alreadyPolling`: Thrown when an attempt is made to start a new polling operation while another one is already running.

## Example

Here's a complete example demonstrating how to use AsyncPoller:
```Swift
import Foundation
import AsyncPoller

func fetchStatusFromServer() async -> String {
    // Simulate an async job
    return "success"
}

let poller = AsyncPoller<String>(
    configuration: .init(pollingInterval: 5, timeoutInterval: 60),
    completionCondition: { result in
        return result == "success"
    },
    pollingJob: {
        return await fetchStatusFromServer()
    }
)

Task {
    do {
        let result = try await poller.start()
        print("Polling succeeded with result: \(result)")
    } catch {
        print("Polling failed with error: \(error)")
    }
}
```

## License
AsyncPoller is released under the MIT license. See LICENSE for details.

## Contributing
Contributions are welcome! Please open an issue or submit a pull request for any changes.

## Contact
For any questions or feedback, please contact petrachkovsergey@gmail.com
