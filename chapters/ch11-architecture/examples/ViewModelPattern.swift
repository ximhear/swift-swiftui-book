// Ch11 - @Observable ViewModel 패턴

import SwiftUI

// MARK: - 도메인 모델

struct Article: Identifiable, Sendable {
    let id: UUID
    var title: String
    var body: String
    var isBookmarked: Bool
    var publishedAt: Date
}

// MARK: - Repository 프로토콜

protocol ArticleRepository: Sendable {
    func fetchAll() async throws -> [Article]
    func update(_ article: Article) async throws
}

// MARK: - ViewModel

@Observable
class ArticleListViewModel {
    private(set) var articles: [Article] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    var searchQuery = ""

    var filteredArticles: [Article] {
        guard !searchQuery.isEmpty else { return articles }
        return articles.filter {
            $0.title.localizedCaseInsensitiveContains(
                searchQuery)
        }
    }

    private let repository: ArticleRepository

    init(repository: ArticleRepository) {
        self.repository = repository
    }

    func loadArticles() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            articles = try await repository.fetchAll()
        } catch {
            self.error = error
        }
    }

    func toggleBookmark(_ article: Article) async {
        guard let index = articles.firstIndex(
            where: { $0.id == article.id })
        else { return }

        articles[index].isBookmarked.toggle()

        do {
            try await repository.update(articles[index])
        } catch {
            articles[index].isBookmarked.toggle()
            self.error = error
        }
    }
}

// MARK: - Mock Repository

struct MockArticleRepository: ArticleRepository {
    var articles: [Article] = [
        Article(id: UUID(), title: "SwiftUI 상태 관리",
                body: "내용", isBookmarked: false,
                publishedAt: .now),
        Article(id: UUID(), title: "Swift Concurrency",
                body: "내용", isBookmarked: true,
                publishedAt: .now),
    ]

    func fetchAll() async throws -> [Article] {
        articles
    }
    func update(_ article: Article) async throws { }
}
