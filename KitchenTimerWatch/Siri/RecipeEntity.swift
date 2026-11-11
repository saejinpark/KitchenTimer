import AppIntents

/// 시리가 "파스타", "라면"처럼 메뉴 이름을 알아듣게 해주는 엔티티.
struct RecipeEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "메뉴"
    static let defaultQuery = RecipeQuery()

    var id: UUID
    var name: String
    var symbol: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }

    init(_ recipe: Recipe) {
        id = recipe.id
        name = recipe.name
        symbol = recipe.symbol
    }
}

struct RecipeQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [RecipeEntity] {
        RecipeStore.shared.recipes
            .filter { identifiers.contains($0.id) }
            .map(RecipeEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [RecipeEntity] {
        let query = normalizedMenuName(string)
        return RecipeStore.shared.recipes
            .filter { normalizedMenuName($0.name).contains(query) }
            .map(RecipeEntity.init)
    }

    /// 시리 문구("파스타 시작해")에 들어갈 수 있는 메뉴 목록.
    @MainActor
    func suggestedEntities() async throws -> [RecipeEntity] {
        RecipeStore.shared.recipes.map(RecipeEntity.init)
    }
}
