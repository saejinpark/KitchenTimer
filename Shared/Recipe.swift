import Foundation
import SwiftUI

/// 메뉴 안의 조리 단계 하나. 단계가 하나뿐인 메뉴가 대부분이다.
struct CookStep: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var seconds: Int
}

/// 폰에서 등록해 두고 워치에서 골라 시작하는 메뉴.
struct Recipe: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var tint: RecipeTint
    var steps: [CookStep]

    var totalSeconds: Int { steps.reduce(0) { $0 + $1.seconds } }

    init(id: UUID = UUID(), name: String, symbol: String, tint: RecipeTint, steps: [CookStep]) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.tint = tint
        self.steps = steps
    }

    // 이전 버전(이모지)으로 저장된 메뉴도 읽을 수 있게 기본값을 채운다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "fork.knife"
        tint = try c.decodeIfPresent(RecipeTint.self, forKey: .tint) ?? .orange
        steps = try c.decode([CookStep].self, forKey: .steps)
    }

    static let samples: [Recipe] = [
        Recipe(name: "라면", symbol: "cup.and.heat.waves.fill", tint: .orange,
               steps: [CookStep(name: "면 삶기", seconds: 4 * 60)]),
        Recipe(name: "파스타", symbol: "fork.knife", tint: .yellow,
               steps: [CookStep(name: "면 삶기", seconds: 9 * 60)]),
        Recipe(name: "반숙 계란", symbol: "cooktop.fill", tint: .teal,
               steps: [CookStep(name: "삶기", seconds: 7 * 60)]),
        Recipe(name: "스테이크", symbol: "frying.pan.fill", tint: .red, steps: [
            CookStep(name: "앞면", seconds: 2 * 60),
            CookStep(name: "뒷면", seconds: 3 * 60),
            CookStep(name: "레스팅", seconds: 5 * 60),
        ]),
    ]

    /// 폰에서 고를 수 있는 주방 관련 심볼.
    static let symbolChoices = [
        "fork.knife", "frying.pan.fill", "cooktop.fill", "stove.fill", "oven.fill", "microwave.fill",
        "flame.fill", "cup.and.heat.waves.fill", "cup.and.saucer.fill", "mug.fill", "drop.fill", "thermometer.medium",
        "carrot.fill", "fish.fill", "leaf.fill", "birthday.cake.fill", "popcorn.fill", "wineglass.fill",
        "takeoutbag.and.cup.and.straw.fill", "timer",
    ]
}

enum RecipeTint: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, brown, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .gray: .gray
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        }
    }
}

/// "4분", "1분 30초", "45초" 형태로 표시한다.
func formatDuration(_ seconds: Int) -> String {
    let m = seconds / 60, s = seconds % 60
    switch (m, s) {
    case (0, _): return "\(s)초"
    case (_, 0): return "\(m)분"
    default: return "\(m)분 \(s)초"
    }
}

/// "9:00", "1:05:00" 처럼 시계 형태로 표시한다.
func formatClock(_ seconds: Int) -> String {
    let h = seconds / 3600, m = seconds / 60 % 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}
