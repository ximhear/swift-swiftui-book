// Ch05 - 매크로 구현 예시 (MyMacrosPlugin 타겟)
// 이 파일은 매크로 플러그인 내에서 사용됩니다.

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

// MARK: - StringifyMacro 구현

public struct StringifyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        guard let argument = node.arguments.first?
            .expression else {
            fatalError("컴파일러 버그: 인자가 없음")
        }
        return "(\(argument), \(literal: argument.description))"
    }
}

// MARK: - URLMacro 구현

public struct URLMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.arguments.first?
            .expression
            .as(StringLiteralExprSyntax.self),
              let value = argument.representedLiteralValue
        else {
            throw MacroError.requiresStringLiteral
        }

        guard Foundation.URL(string: value) != nil else {
            // 컴파일 타임 진단 메시지
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

// MARK: - 에러 및 진단

enum MacroError: Error, CustomStringConvertible {
    case requiresStringLiteral

    var description: String {
        switch self {
        case .requiresStringLiteral:
            return "문자열 리터럴이 필요합니다"
        }
    }
}

struct SimpleDiagnostic: DiagnosticMessage {
    let message: String
    let severity: DiagnosticSeverity
    var diagnosticID: MessageID {
        MessageID(domain: "MyMacros", id: message)
    }
}

// MARK: - 플러그인 등록

@main
struct MyMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StringifyMacro.self,
        URLMacro.self,
    ]
}
