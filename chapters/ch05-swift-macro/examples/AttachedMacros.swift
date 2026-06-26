// Ch05 - Attached Macro 선언과 사용 예시

import Foundation

// MARK: - @UserDefault 매크로

@attached(accessor)
public macro UserDefault(
    key: String,
    defaultValue: Any? = nil
) = #externalMacro(
    module: "MyMacrosPlugin",
    type: "UserDefaultMacro"
)

// 사용
struct Settings {
    @UserDefault(key: "app_theme", defaultValue: "light")
    var theme: String

    @UserDefault(key: "font_size", defaultValue: 16)
    var fontSize: Int
}

// MARK: - @AutoInit 매크로

@attached(member, names: named(init))
public macro AutoInit() = #externalMacro(
    module: "MyMacrosPlugin",
    type: "AutoInitMacro"
)

// 사용
protocol UserRepository {}

@AutoInit
class UserViewModel {
    let userId: String
    let repository: UserRepository
    var isLoading: Bool = false
}

// MARK: - @Builder 매크로

@attached(member, names: named(Builder), named(builder))
public macro Builder() = #externalMacro(
    module: "MyMacrosPlugin",
    type: "BuilderMacro"
)

// 사용
@Builder
struct NetworkRequest {
    var url: URL
    var method: String = "GET"
    var headers: [String: String] = [:]
    var body: Data?
    var timeout: TimeInterval = 30
}
