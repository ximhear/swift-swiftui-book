// Ch01 - 타입 시스템 활용 실전 패턴

import Foundation

// MARK: - 패턴 1: Phantom Type

enum Draft {}
enum Published {}

struct Article<Status> {
    let title: String
    let content: String
    let author: String
}

extension Article where Status == Draft {
    func edit(content: String) -> Article<Draft> {
        Article<Draft>(
            title: title,
            content: content,
            author: author
        )
    }

    func publish() -> Article<Published> {
        Article<Published>(
            title: title,
            content: content,
            author: author
        )
    }
}

extension Article where Status == Published {
    func shareURL() -> URL {
        URL(string: "https://blog.example.com/\(title)")!
    }
}

func demonstratePhantomType() {
    let draft = Article<Draft>(
        title: "Swift 타입 시스템",
        content: "초안 내용",
        author: "홍길동"
    )
    let edited = draft.edit(content: "수정된 내용")
    let published = edited.publish()
    let url = published.shareURL()
    print("공유 URL: \(url)")

    // ❌ 컴파일 에러들:
    // draft.shareURL()
    // published.edit(content: "...")
}

// MARK: - 패턴 2: 타입 안전한 식별자

struct Identifier<Entity>: Hashable {
    let rawValue: String
}

struct User {
    let id: Identifier<User>
    let name: String
}

struct Order {
    let id: Identifier<Order>
    let amount: Decimal
}

func fetchUser(id: Identifier<User>) -> User? {
    nil
}

func demonstrateTypeSafeID() {
    let userId = Identifier<User>(rawValue: "user_123")
    let orderId = Identifier<Order>(rawValue: "order_456")

    _ = fetchUser(id: userId)   // ✅ 정상
    // fetchUser(id: orderId)   // ❌ 컴파일 에러
}

// MARK: - 패턴 3: Result Builder

protocol HTMLNode {
    func render() -> String
}

struct Paragraph: HTMLNode {
    let text: String
    func render() -> String { "<p>\(text)</p>" }
}

struct Header: HTMLNode {
    let level: Int
    let text: String
    func render() -> String {
        "<h\(level)>\(text)</h\(level)>"
    }
}

@resultBuilder
struct HTMLBuilder {
    static func buildBlock(
        _ components: HTMLNode...
    ) -> [HTMLNode] {
        components
    }

    static func buildOptional(
        _ component: [HTMLNode]?
    ) -> [HTMLNode] {
        component ?? []
    }

    static func buildEither(
        first component: [HTMLNode]
    ) -> [HTMLNode] {
        component
    }

    static func buildEither(
        second component: [HTMLNode]
    ) -> [HTMLNode] {
        component
    }
}

struct HTMLDocument {
    let children: [HTMLNode]

    init(@HTMLBuilder content: () -> [HTMLNode]) {
        children = content()
    }

    func render() -> String {
        children.map { $0.render() }
            .joined(separator: "\n")
    }
}

func demonstrateResultBuilder() {
    let doc = HTMLDocument {
        Header(level: 1, text: "Swift 타입 시스템")
        Paragraph(text: "값 타입과 참조 타입의 차이")
        Paragraph(text: "Copy-on-Write의 동작 원리")
    }
    print(doc.render())
}
