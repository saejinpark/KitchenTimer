import Foundation

/// 어떤 메뉴를 얼마나 자주, 마지막으로 무엇을 넣었는지. 피크 타임에 한 번에 누르게 해 준다.
struct RecipeUsage: Codable, Equatable {
    private(set) var counts: [UUID: Int] = [:]
    private(set) var lastID: UUID?

    mutating func record(_ id: UUID) {
        counts[id, default: 0] += 1
        lastID = id
    }

    /// 많이 쓴 순서. 같으면 원래(폰에서 정한) 순서를 지킨다.
    func ranked(_ recipes: [Recipe]) -> [Recipe] {
        recipes.enumerated()
            .sorted { a, b in
                let ca = counts[a.element.id, default: 0], cb = counts[b.element.id, default: 0]
                return ca != cb ? ca > cb : a.offset < b.offset
            }
            .map(\.element)
    }

    /// 빠른 추가에 띄울 메뉴. 한 번이라도 쓴 것만, 많이 쓴 순서로.
    func favorites(_ recipes: [Recipe], limit: Int = 4) -> [Recipe] {
        Array(ranked(recipes).filter { counts[$0.id, default: 0] > 0 }.prefix(limit))
    }

    /// "하나 더"에 쓸 마지막 메뉴. 폰에서 지웠으면 없다.
    func last(in recipes: [Recipe]) -> Recipe? {
        recipes.first { $0.id == lastID }
    }
}
