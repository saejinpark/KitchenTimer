import Foundation
import Observation

/// 워치에만 있는 주방 설정과 사용 기록.
@MainActor @Observable
final class KitchenPrefs {
    static let shared = KitchenPrefs()

    /// 추가할 때 화구 번호를 묻는다(식당 모드). 집에서는 끄는 게 빠르다.
    var askBurner: Bool {
        didSet { UserDefaults.standard.set(askBurner, forKey: "askBurner") }
    }

    /// 화구 개수. 번호 버튼을 이만큼 보여 준다.
    var burnerCount: Int {
        didSet { UserDefaults.standard.set(burnerCount, forKey: "burnerCount") }
    }

    /// "시계로 돌아가기" 안내를 확인했는지. 식당 모드를 처음 켤 때 한 번 띄운다.
    var stayOnGuideSeen: Bool {
        didSet { UserDefaults.standard.set(stayOnGuideSeen, forKey: "stayOnGuideSeen") }
    }

    private(set) var usage: RecipeUsage {
        didSet {
            if let data = try? JSONEncoder().encode(usage) {
                UserDefaults.standard.set(data, forKey: "recipeUsage")
            }
        }
    }

    static let burnerRange = 2...9

    private init() {
        let defaults = UserDefaults.standard
        askBurner = defaults.bool(forKey: "askBurner")
        stayOnGuideSeen = defaults.bool(forKey: "stayOnGuideSeen")
        let count = defaults.integer(forKey: "burnerCount")
        burnerCount = Self.burnerRange.contains(count) ? count : 6
        usage = defaults.data(forKey: "recipeUsage")
            .flatMap { try? JSONDecoder().decode(RecipeUsage.self, from: $0) } ?? RecipeUsage()
    }

    func recordUse(_ recipe: Recipe) {
        usage.record(recipe.id)
    }
}
