// Ch02 - Type Erasure 패턴

import Foundation

// MARK: - 클로저 기반 Type Erasure

protocol Renderer {
    associatedtype Output
    func render(content: String) -> Output
}

struct HTMLRenderer: Renderer {
    func render(content: String) -> String {
        "<p>\(content)</p>"
    }
}

struct MarkdownRenderer: Renderer {
    func render(content: String) -> String {
        "**\(content)**"
    }
}

struct AnyRenderer<Output> {
    private let _render: (String) -> Output

    init<R: Renderer>(_ renderer: R)
        where R.Output == Output {
        _render = renderer.render
    }

    func render(content: String) -> Output {
        _render(content)
    }
}

func demonstrateClosureErasure() {
    let renderers: [AnyRenderer<String>] = [
        AnyRenderer(HTMLRenderer()),
        AnyRenderer(MarkdownRenderer())
    ]

    for renderer in renderers {
        print(renderer.render(content: "Hello"))
    }
}

// MARK: - Box 패턴 Type Erasure

struct Article: Identifiable {
    let id: UUID
    var title: String
    var body: String
}

protocol DataSource {
    associatedtype Item: Identifiable

    var items: [Item] { get }
    func item(at index: Int) -> Item
    func search(query: String) -> [Item]
}

private class AnyDataSourceBox<Item: Identifiable> {
    func getItems() -> [Item] { fatalError() }
    func item(at index: Int) -> Item { fatalError() }
    func search(query: String) -> [Item] { fatalError() }
}

private class DataSourceBox<
    Source: DataSource
>: AnyDataSourceBox<Source.Item> {
    private let source: Source

    init(_ source: Source) { self.source = source }

    override func getItems() -> [Source.Item] {
        source.items
    }
    override func item(at index: Int) -> Source.Item {
        source.item(at: index)
    }
    override func search(
        query: String
    ) -> [Source.Item] {
        source.search(query: query)
    }
}

struct AnyDataSource<Item: Identifiable> {
    private let box: AnyDataSourceBox<Item>

    init<Source: DataSource>(
        _ source: Source
    ) where Source.Item == Item {
        box = DataSourceBox(source)
    }

    var items: [Item] { box.getItems() }
    func item(at index: Int) -> Item {
        box.item(at: index)
    }
    func search(query: String) -> [Item] {
        box.search(query: query)
    }
}

// MARK: - Swift 5.7+ 대안: any + Primary Associated Type

protocol ModernDataSource<Item> {
    associatedtype Item: Identifiable

    var items: [Item] { get }
    func item(at index: Int) -> Item
    func search(query: String) -> [Item]
}

class ViewModel {
    private var dataSource: any ModernDataSource<Article>

    init(dataSource: any ModernDataSource<Article>) {
        self.dataSource = dataSource
    }

    func loadArticles() -> [Article] {
        dataSource.items
    }

    func switchDataSource(
        _ newSource: any ModernDataSource<Article>
    ) {
        dataSource = newSource
    }
}
