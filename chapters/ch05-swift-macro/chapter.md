# Chapter 5. Swift Macro

> Swift 5.9에서 도입된 매크로(Macro)는 컴파일 타임에 코드를 생성하는 메타프로그래밍(Metaprogramming) 도구입니다. 보일러플레이트 코드를 줄이고, 커스텀 진단 메시지를 제공하며, 새로운 패턴을 언어 수준에서 지원할 수 있습니다. 이 장에서는 매크로의 동작 원리를 이해하고, 실무에서 유용한 매크로를 직접 작성하는 방법을 배웁니다.

---

## 5.1 매크로의 종류와 동작 원리

### 매크로가 해결하는 문제

Swift 개발에서 반복적으로 작성해야 하는 코드가 있습니다:

```swift
// Codable의 커스텀 키 매핑 — 매번 수동 작성
struct User: Codable {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case emailAddress = "email_address"
    }
}
```

매크로를 사용하면:

```swift
@CodingKeys(.snakeCase)
struct User: Codable {
    let firstName: String
    let lastName: String
    let emailAddress: String
    // CodingKeys가 자동으로 생성됨!
}
```

### 두 가지 매크로 종류

Swift 매크로는 크게 두 종류로 나뉩니다:

**1. Freestanding Macro (독립 매크로)**

`#` 접두사로 사용하며, 역할(role)은 `expression`(표현식 생성)과 `declaration`(선언 생성) 두 가지입니다.

```swift
// expression role — 표현식을 생성 (#으로 시작)
let url = #URL("https://api.example.com/users")
// 컴파일 타임에 URL 유효성 검증 + URL 인스턴스 생성

// Swift 표준 라이브러리의 expression 매크로
let pred = #Predicate<User> { $0.age > 18 }
```

> **Note**: `#warning("...")`, `#error("...")`는 매크로처럼 보이지만 매크로가 아니라 매크로 시스템(Swift 5.9) 이전부터 존재한 컴파일러 지시어(compiler directive, SE-0196)입니다. `#` 문법만 공유할 뿐 `macro` 선언이나 플러그인으로 구현된 것이 아닙니다.

**2. Attached Macro (부착 매크로)**

`@` 접두사로 선언에 부착하여 코드를 추가합니다.

```swift
// @Observable — 가장 유명한 부착 매크로
@Observable
class UserSettings {
    var theme: String = "light"
    var fontSize: Int = 16
}
// 프로퍼티 변경 추적 코드가 자동으로 생성됨
```

### Attached Macro의 5가지 역할(Role)

| 역할 | 설명 | 예시 |
|------|------|------|
| `@attached(peer)` | 같은 스코프에 새 선언 추가 | `@AddAsync` — 동기 함수 옆에 async 버전 생성 |
| `@attached(accessor)` | 프로퍼티에 접근자 추가 | `@UserDefault` — get/set으로 UserDefaults 연결 |
| `@attached(member)` | 타입에 새 멤버 추가 | `@Observable` — 내부에 추적 코드 추가 |
| `@attached(memberAttribute)` | 기존 멤버에 속성 추가 | 모든 프로퍼티에 `@objc` 부여 |
| `@attached(extension)` | 타입에 extension 추가 | 프로토콜 준수 자동 생성 |

하나의 매크로가 **여러 역할을 동시에** 가질 수 있습니다:

```swift
// @Observable은 member + memberAttribute + extension을 조합
@attached(member, names: named(_$observationRegistrar), ...)
@attached(memberAttribute)
@attached(extension, conformances: Observable)
public macro Observable() = #externalMacro(...)
```

### 매크로의 동작 흐름

매크로는 소스 코드를 추상 구문 트리(AST, Abstract Syntax Tree)로 파싱한 뒤, 그 트리를 입력으로 받아 새 코드를 생성합니다.

```mermaid
graph LR
    A[소스 코드] --> B[Swift 컴파일러]
    B --> C[매크로 발견]
    C --> D[SwiftSyntax로<br/>AST 파싱]
    D --> E[매크로 플러그인<br/>별도 프로세스에서 실행]
    E --> F[생성된 코드<br/>SwiftSyntax 반환]
    F --> G[원본에 삽입]
    G --> H[컴파일 계속]
```

매크로 플러그인은 **별도 프로세스**에서 실행되며, macOS에서는 기본적으로 샌드박스(sandbox)가 적용되어 파일 시스템·네트워크 접근이 차단됩니다. 따라서 매크로는 사실상 입력된 구문 트리만을 기반으로 코드를 생성하게 됩니다.

> **Warning**: 이 샌드박스는 컴파일러가 강제하는 보안 조치이며 `-disable-sandbox` 옵션으로 끌 수 있습니다. 즉 언어가 결정론을 *보장*하는 것은 아니므로, 매크로 구현은 입력 구문 트리 외의 외부 상태에 의존하지 않도록 직접 설계해야 합니다.

---

## 5.2 Freestanding Macro 작성

### 프로젝트 설정

매크로는 Swift Package로 구성합니다:

**파일: Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "MyMacros",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(name: "MyMacros", targets: ["MyMacros"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "600.0.0"
        ),
    ],
    targets: [
        // 매크로 구현 (컴파일러 플러그인)
        .macro(
            name: "MyMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros",
                         package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin",
                         package: "swift-syntax"),
            ]
        ),
        // 매크로 선언 (사용자에게 노출)
        .target(
            name: "MyMacros",
            dependencies: ["MyMacrosPlugin"]
        ),
        // 테스트
        .testTarget(
            name: "MyMacrosTests",
            dependencies: [
                "MyMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport",
                         package: "swift-syntax"),
            ]
        ),
    ]
)
```

### 예제: #stringify 매크로

🟢 기본

가장 간단한 표현식 매크로부터 시작합니다:

**선언 (MyMacros 타겟):**

**파일: Sources/MyMacros/Macros.swift**

```swift
/// 표현식을 실행하고, 원본 코드 문자열과 결과를 튜플로 반환
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) =
    #externalMacro(module: "MyMacrosPlugin",
                   type: "StringifyMacro")
```

**구현 (MyMacrosPlugin 타겟):**

**파일: Sources/MyMacrosPlugin/StringifyMacro.swift**

```swift
import SwiftSyntax
import SwiftSyntaxMacros

public struct StringifyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        guard let argument = node.arguments.first?.expression
        else {
            fatalError("컴파일러 버그: 인자가 없음")
        }
        
        return "(\(argument), \(literal: argument.description))"
    }
}
```

**사용:**

```swift
let (result, code) = #stringify(2 + 3)
print("\(code) = \(result)")  // "2 + 3 = 5"
```

### 예제: #URL 매크로 — 컴파일 타임 검증

🟡 중급

**선언 (MyMacros 타겟):**

**파일: Sources/MyMacros/Macros.swift**

```swift
import Foundation

@freestanding(expression)
public macro URL(_ string: String) -> URL =
    #externalMacro(module: "MyMacrosPlugin",
                   type: "URLMacro")
```

**구현 (MyMacrosPlugin 타겟):**

**파일: Sources/MyMacrosPlugin/URLMacro.swift**

```swift
import Foundation
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct URLMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.arguments.first?
            .expression.as(StringLiteralExprSyntax.self),
              let value = argument.representedLiteralValue
        else {
            throw MacroError.requiresStringLiteral
        }
        
        // 컴파일 타임에 URL 유효성 검증
        guard URL(string: value) != nil else {
            context.diagnose(Diagnostic(
                node: argument,
                message: SimpleDiagnostic(
                    message: "유효하지 않은 URL: \(value)",
                    severity: .error
                )
            ))
            return "URL(string: \(argument))!"
        }
        
        return "URL(string: \(argument))!"
    }
}

enum MacroError: Error, CustomStringConvertible {
    case requiresStringLiteral
    
    var description: String {
        switch self {
        case .requiresStringLiteral:
            return "#URL은 문자열 리터럴이 필요합니다"
        }
    }
}

// 진단 메시지를 표현하는 최소 구현
struct SimpleDiagnostic: DiagnosticMessage {
    let message: String
    let severity: DiagnosticSeverity
    var diagnosticID: MessageID {
        MessageID(domain: "MyMacros", id: message)
    }
}
```

---

## 5.3 Attached Macro 작성

### 예제: @UserDefault 프로퍼티 매크로

🟡 중급

UserDefaults와 연결되는 프로퍼티를 자동 생성하는 매크로:

**선언:**

```swift
@attached(accessor)
public macro UserDefault(
    key: String,
    defaultValue: Any? = nil
) = #externalMacro(
    module: "MyMacrosPlugin",
    type: "UserDefaultMacro"
)
```

**사용:**

```swift
struct Settings {
    @UserDefault(key: "app_theme", defaultValue: "light")
    var theme: String
    
    @UserDefault(key: "font_size", defaultValue: 16)
    var fontSize: Int
    
    @UserDefault(key: "is_premium")
    var isPremium: Bool
}

// 매크로가 생성하는 코드:
// var theme: String {
//     get {
//         UserDefaults.standard.object(forKey: "app_theme")
//             as? String ?? "light"
//     }
//     set {
//         UserDefaults.standard.set(newValue,
//             forKey: "app_theme")
//     }
// }
```

### 예제: @EnumSubset — Member Macro

🔴 고급

열거형의 서브셋을 자동 생성하는 매크로:

```swift
@attached(member, names: arbitrary)
@attached(extension, conformances: CaseIterable)
public macro EnumSubset<SuperEnum>(
    _ cases: SuperEnum...
) = #externalMacro(
    module: "MyMacrosPlugin",
    type: "EnumSubsetMacro"
)
```

**사용:**

```swift
enum Permission {
    case read, write, delete, admin
}

// 읽기 전용 권한 서브셋
@EnumSubset<Permission>(.read)
enum ReadOnlyPermission { }

// 매크로가 생성:
// enum ReadOnlyPermission: CaseIterable {
//     case read
//     
//     var superEnum: Permission {
//         switch self {
//         case .read: return .read
//         }
//     }
// }
```

---

## 5.4 SwiftSyntax 활용

### SwiftSyntax란

SwiftSyntax는 Swift 소스 코드를 **추상 구문 트리(AST)**로 파싱하고 조작하는 라이브러리입니다. 매크로 구현의 핵심 도구입니다.

### 주요 타입 계층

```text
SyntaxProtocol
├── DeclSyntaxProtocol (선언)
│   ├── StructDeclSyntax
│   ├── ClassDeclSyntax
│   ├── EnumDeclSyntax
│   ├── FunctionDeclSyntax
│   └── VariableDeclSyntax
├── ExprSyntaxProtocol (표현식)
│   ├── FunctionCallExprSyntax
│   ├── StringLiteralExprSyntax
│   ├── MemberAccessExprSyntax
│   └── IfExprSyntax        // if/switch는 SE-0380으로 표현식이 됨
├── StmtSyntaxProtocol (구문)
│   ├── ForStmtSyntax
│   ├── WhileStmtSyntax
│   ├── GuardStmtSyntax
│   └── ReturnStmtSyntax
└── TypeSyntaxProtocol (타입)
    ├── IdentifierTypeSyntax
    └── OptionalTypeSyntax
```

### AST 탐색과 조작

🔴 고급

```swift
import SwiftSyntax

// 구조체의 모든 저장 프로퍼티 이름 추출
func storedProperties(
    of structDecl: StructDeclSyntax
) -> [(name: String, type: String)] {
    structDecl.memberBlock.members.compactMap { member in
        guard let variable = member.decl
            .as(VariableDeclSyntax.self),
              variable.bindingSpecifier.text == "var"
                || variable.bindingSpecifier.text == "let",
              let binding = variable.bindings.first,
              // 계산 프로퍼티(접근자 블록 보유)는 저장 프로퍼티가 아니므로 제외
              binding.accessorBlock == nil,
              let pattern = binding.pattern
                  .as(IdentifierPatternSyntax.self),
              let type = binding.typeAnnotation?.type
        else { return nil }
        
        return (
            name: pattern.identifier.text,
            type: type.description.trimmingCharacters(
                in: .whitespaces)
        )
    }
}
```

### 매크로 테스트

🟡 중급

> **Note**: 매크로는 컴파일 타임에 코드를 생성하므로 일반적인 단위 테스트로는 동작을 확인하기 어렵습니다. SwiftSyntax는 확장 결과와 진단 메시지를 문자열 단위로 검증하는 전용 도구(`assertMacroExpansion`)를 제공하므로, 매크로 구현은 이 도구로 반드시 테스트하는 것을 권장합니다.

SwiftSyntax는 테스트를 위한 전용 프레임워크를 제공합니다:

```swift
import SwiftSyntaxMacrosTestSupport
import XCTest

final class URLMacroTests: XCTestCase {
    let macros: [String: Macro.Type] = [
        "URL": URLMacro.self,
    ]
    
    func testValidURL() throws {
        assertMacroExpansion(
            """
            #URL("https://example.com")
            """,
            expandedSource: """
            URL(string: "https://example.com")!
            """,
            macros: macros
        )
    }
    
    func testInvalidURL() throws {
        assertMacroExpansion(
            """
            #URL("not a url ☺️")
            """,
            expandedSource: """
            URL(string: "not a url ☺️")!
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "유효하지 않은 URL: not a url ☺️",
                    line: 1,
                    column: 6
                )
            ],
            macros: macros
        )
    }
}
```

---

## 5.5 실무에서 유용한 매크로 패턴

### 패턴 1: @AutoInit — 자동 이니셜라이저 생성

🟡 중급

```swift
@attached(member, names: named(init))
public macro AutoInit() = #externalMacro(
    module: "MyMacrosPlugin",
    type: "AutoInitMacro"
)

// 사용
@AutoInit
class UserViewModel {
    let userId: String
    let repository: UserRepository
    var isLoading: Bool = false
    
    // 매크로가 생성:
    // init(userId: String, repository: UserRepository,
    //      isLoading: Bool = false) {
    //     self.userId = userId
    //     self.repository = repository
    //     self.isLoading = isLoading
    // }
}
```

### 패턴 2: @Entry — SwiftUI Environment 키 보일러플레이트 제거

🟡 중급

커스텀 Environment 값을 추가하려면 전통적으로 키 타입과 `EnvironmentValues` 확장을 모두 작성해야 했습니다. Xcode 16/iOS 18에서 도입된 공식 매크로 `@Entry`는 이 보일러플레이트를 한 줄로 줄여줍니다.

```swift
import SwiftUI

// Before: 수동으로 키 타입 + EnvironmentValues 확장이 필요
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .light
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
```

```swift
import SwiftUI

// After: EnvironmentValues 확장 내 프로퍼티에 @Entry 한 줄
extension EnvironmentValues {
    @Entry var theme: Theme = .light
}
```

> **Note**: `@Entry`는 `accessor` + `peer` 역할의 attached 매크로입니다. 매크로 역할 규칙상 `extension`/`peer`/`member` 역할은 *다른 타입*에 대한 확장 선언을 만들어낼 수 없으므로, 반드시 `extension EnvironmentValues { ... }` 내부 프로퍼티에 부착해야 키 타입과 접근자가 생성됩니다. (직접 만든 매크로로 동일 동작을 구현할 때도 같은 제약이 적용됩니다.)

### 패턴 3: @Builder — 빌더 패턴 자동 생성

🔴 고급

```swift
@attached(member, names: named(Builder), named(builder))
public macro Builder() = #externalMacro(
    module: "MyMacrosPlugin",
    type: "BuilderMacro"
)

@Builder
struct NetworkRequest {
    var url: URL
    var method: String = "GET"
    var headers: [String: String] = [:]
    var body: Data?
    var timeout: TimeInterval = 30
    
    // 매크로가 생성하는 Builder 클래스:
    // class Builder {
    //     var url: URL
    //     var method: String = "GET"
    //     var headers: [String: String] = [:]
    //     var body: Data?
    //     var timeout: TimeInterval = 30
    //
    //     func method(_ value: String) -> Builder {
    //         self.method = value
    //         return self
    //     }
    //     // ... 각 프로퍼티에 대한 setter
    //
    //     func build() -> NetworkRequest { ... }
    // }
}

// 사용
let request = NetworkRequest
    .builder(url: apiURL)
    .method("POST")
    .headers(["Content-Type": "application/json"])
    .body(jsonData)
    .timeout(60)
    .build()
```

---

## 5.6 매크로 사용 시 주의사항

### 디버깅

매크로가 생성한 코드는 Xcode에서 확인할 수 있습니다.
1. 매크로 적용 부분에서 우클릭합니다.
2. "Expand Macro"를 선택합니다.
3. 생성된 코드를 직접 확인합니다.

### 성능 고려

- 매크로는 **컴파일 타임에만** 실행되므로 런타임 성능에 영향을 주지 않습니다.
- 하지만 복잡한 매크로는 **컴파일 시간을 증가**시킬 수 있습니다.
- 대규모 프로젝트에서는 매크로를 별도 패키지로 분리하여 캐싱 효과를 얻을 수 있습니다.

> **Warning**: 매크로 플러그인은 빌드 시 SwiftSyntax를 함께 컴파일해야 하므로, 매크로를 처음 도입하면 클린 빌드 시간이 눈에 띄게 늘 수 있습니다. 매크로 구현을 별도 패키지로 분리해 증분 빌드 캐시를 활용하고, 확장 로직이 무거워지지 않도록 구현을 단순하게 유지하세요.

### 매크로 vs 다른 대안

| 도구 | 장점 | 단점 |
|------|------|------|
| 매크로 | 컴파일 타임 검증, IDE 통합 | 복잡한 구현, SwiftSyntax 의존 |
| 프로토콜 기본 구현 | 간단, 별도 도구 불필요 | 보일러플레이트 완전 제거 불가 |
| 코드 생성 (Sourcery 등) | 유연, 외부 데이터 사용 가능 | 빌드 단계 추가 필요 |
| Property Wrapper | 간단한 프로퍼티 래핑 | 생성 능력 제한적 |

---

## 정리

- **Freestanding Macro (`#`)**: 표현식이나 선언을 생성합니다. 컴파일 타임 검증에 유용합니다.

- **Attached Macro (`@`)**: 기존 선언에 코드를 추가합니다. peer, accessor, member, memberAttribute, extension 5가지 역할이 있습니다.

- **SwiftSyntax**: 매크로 구현의 핵심 도구로, AST를 파싱하고 조작합니다. 매크로는 별도 프로세스에서 샌드박스 내 실행됩니다.

- **매크로 테스트**: `assertMacroExpansion`으로 입력과 예상 출력, 진단 메시지를 검증합니다.

- **실전 패턴**: `@AutoInit`, `@Builder` 같은 매크로를 직접 작성하거나 공식 `@Entry` 매크로를 활용해 보일러플레이트를 크게 줄일 수 있습니다.

Part 1이 끝났습니다. 다음 Part 2에서는 **SwiftUI 아키텍처**를 다루며, SwiftUI 렌더링 엔진의 내부 동작부터 시작합니다.
