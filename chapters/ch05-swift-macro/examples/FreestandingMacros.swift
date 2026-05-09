// Ch05 - Freestanding Macro 예제

import Foundation

// MARK: - 매크로 선언 (사용자 측)

// #stringify: 표현식과 코드 문자열을 함께 반환
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) =
    #externalMacro(module: "MyMacrosPlugin",
                   type: "StringifyMacro")

// #URL: 컴파일 타임 URL 유효성 검증
@freestanding(expression)
public macro URL(_ string: String) -> URL =
    #externalMacro(module: "MyMacrosPlugin",
                   type: "URLMacro")

// MARK: - 사용 예시

func demonstrateMacros() {
    // #stringify
    let (result, code) = #stringify(2 + 3)
    print("\(code) = \(result)")  // "2 + 3 = 5"

    // #URL — 잘못된 URL은 컴파일 에러
    let url = #URL("https://api.example.com/users")
    print("URL: \(url)")
}
