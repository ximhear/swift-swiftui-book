// Ch02 - 실전 설계 사례: 플러그인 아키텍처

import Foundation

// MARK: - 프로토콜 설계

protocol PluginConfig: Codable {
    static var `default`: Self { get }
}

protocol Plugin<Configuration> {
    associatedtype Configuration: PluginConfig
    associatedtype Output

    var name: String { get }
    var version: String { get }

    func configure(with config: Configuration) throws
    func execute() async throws -> Output
}

// MARK: - Type Erasure 래퍼

struct AnyPlugin {
    let name: String
    let version: String
    private let _execute: () async throws -> Any

    init<P: Plugin>(_ plugin: P) {
        name = plugin.name
        version = plugin.version
        _execute = { try await plugin.execute() }
    }

    func execute() async throws -> Any {
        try await _execute()
    }
}

// MARK: - 플러그인 매니저

actor PluginManager {
    private var plugins: [String: AnyPlugin] = [:]

    func register<P: Plugin>(_ plugin: P) {
        let erased = AnyPlugin(plugin)
        plugins[erased.name] = erased
    }

    func executeAll() async throws -> [String: Any] {
        var results: [String: Any] = [:]
        for (name, plugin) in plugins {
            results[name] = try await plugin.execute()
        }
        return results
    }
}

// MARK: - 구체 플러그인 구현

struct AnalyticsConfig: PluginConfig {
    var trackingId: String
    var sampleRate: Double

    static var `default`: Self {
        AnalyticsConfig(
            trackingId: "default",
            sampleRate: 1.0
        )
    }
}

struct AnalyticsPlugin: Plugin {
    var name: String { "analytics" }
    var version: String { "2.1.0" }

    private var config: AnalyticsConfig

    init() {
        config = .default
    }

    func configure(
        with config: AnalyticsConfig
    ) throws {
        // 설정 검증 및 적용
    }

    func execute() async throws -> [String: Int] {
        ["pageViews": 1234, "sessions": 567]
    }
}

// MARK: - 조건부 확장

extension Plugin where Output: Codable {
    func exportResult() async throws -> Data {
        let output = try await execute()
        return try JSONEncoder().encode(output)
    }
}

protocol Validatable {
    func validate() throws
}

extension Plugin where Configuration: Validatable {
    func safeExecute() async throws -> Output {
        let config = Configuration.default
        try config.validate()
        try configure(with: config)
        return try await execute()
    }
}
