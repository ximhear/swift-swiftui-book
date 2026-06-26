// Ch03 - TaskGroup과 AsyncStream 패턴

import Foundation

// MARK: - TaskGroup 기본

func fetchAllAvatars(
    userIds: [String]
) async throws -> [String: Data] {
    try await withThrowingTaskGroup(
        of: (String, Data).self
    ) { group in
        for userId in userIds {
            group.addTask {
                let url = URL(
                    string: "https://api.example.com/avatar/\(userId)"
                )!
                let (data, _) = try await URLSession
                    .shared.data(from: url)
                return (userId, data)
            }
        }

        var avatars: [String: Data] = [:]
        for try await (userId, data) in group {
            avatars[userId] = data
        }
        return avatars
    }
}

// MARK: - 동시성 제한 TaskGroup

func downloadFiles(
    urls: [URL],
    maxConcurrency: Int = 5
) async throws -> [URL: Data] {
    try await withThrowingTaskGroup(
        of: (URL, Data).self
    ) { group in
        var results: [URL: Data] = [:]
        var iterator = urls.makeIterator()

        // 초기 배치
        for _ in 0..<min(maxConcurrency, urls.count) {
            if let url = iterator.next() {
                group.addTask {
                    let (data, _) = try await URLSession
                        .shared.data(from: url)
                    return (url, data)
                }
            }
        }

        // 하나 완료될 때마다 새 작업 추가
        for try await (url, data) in group {
            results[url] = data
            if let nextURL = iterator.next() {
                group.addTask {
                    let (data, _) = try await URLSession
                        .shared.data(from: nextURL)
                    return (nextURL, data)
                }
            }
        }

        return results
    }
}

// MARK: - 재시도 로직

func withRetry<T: Sendable>(
    maxAttempts: Int = 3,
    delay: Duration = .seconds(1),
    backoffMultiplier: Double = 2.0,
    operation: @Sendable () async throws -> T
) async throws -> T {
    var lastError: Error?
    // attoseconds까지 반영해야 1초 미만 delay(예: .milliseconds(500))가 0으로 잘리지 않음
    var currentDelaySeconds =
        Double(delay.components.seconds)
        + Double(delay.components.attoseconds) / 1e18

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxAttempts {
                try await Task.sleep(
                    for: .seconds(currentDelaySeconds))
                currentDelaySeconds *= backoffMultiplier
            }
        }
    }

    throw lastError!
}

// MARK: - AsyncStream

func timerStream(
    interval: Duration
) -> AsyncStream<Date> {
    AsyncStream { continuation in
        let task = Task {
            while !Task.isCancelled {
                continuation.yield(Date.now)
                try? await Task.sleep(for: interval)
            }
            continuation.finish()
        }

        continuation.onTermination = { _ in
            task.cancel()
        }
    }
}
