import Foundation
import Observation

/// 메뉴 목록. 폰에서는 편집할 때마다 워치로 보내고, 워치에서는 받은 목록을 저장한다.
@MainActor @Observable
final class RecipeStore {
    static let shared = RecipeStore()

    var recipes: [Recipe] {
        didSet { save() }
    }

    private let storageKey = "recipes"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Recipe].self, from: data) {
            recipes = saved
        } else {
            recipes = Recipe.samples
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(recipes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        #if os(iOS)
        RecipeSync.shared.send(recipes)
        #endif
    }
}
