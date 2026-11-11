import Observation
import SwiftUI
import WatchKit

/// 메뉴를 골랐을 때: 식당 모드면 화구 번호를 묻고, 아니면 바로 시작한다.
/// 메뉴 페이지, 빠른 추가, "하나 더"가 모두 이 흐름을 쓴다.
@MainActor @Observable
final class AddFlow {
    static let shared = AddFlow()

    /// 화구를 고르는 중인 메뉴. 있으면 화구 선택 화면이 뜬다.
    var pendingRecipe: Recipe?

    /// 시작한 뒤 할 일(큐 페이지로 돌아가기).
    var onStarted: () -> Void = {}

    func choose(_ recipe: Recipe) {
        if KitchenPrefs.shared.askBurner {
            pendingRecipe = recipe
        } else {
            start(recipe, burner: nil)
        }
    }

    func start(_ recipe: Recipe, burner: Int?) {
        pendingRecipe = nil
        guard TimerQueue.shared.add(recipe, burner: burner) != nil else { return }
        KitchenPrefs.shared.recordUse(recipe)
        WKInterfaceDevice.current().play(.start)
        onStarted()
    }
}

/// 큰 숫자 버튼으로 화구를 고른다. 이미 냄비가 올라간 화구는 불꽃 표시.
struct BurnerPicker: View {
    @Environment(KitchenPrefs.self) private var prefs
    @Environment(TimerQueue.self) private var queue
    @Environment(AddFlow.self) private var flow
    let recipe: Recipe

    var body: some View {
        let occupied = ActiveTimer.occupiedBurners(queue.timers)
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    RecipeIcon(symbol: recipe.symbol, tint: recipe.tint, size: 24)
                    Text(recipe.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text("어느 화구에 올렸어요?")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(1...prefs.burnerCount, id: \.self) { number in
                        let busy = occupied.contains(number)
                        Button {
                            flow.start(recipe, burner: number)
                        } label: {
                            Text("\(number)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(busy ? .secondary : .primary)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(busy ? Color.white.opacity(0.08) : recipe.tint.color.opacity(0.4))
                                )
                                .overlay(alignment: .topTrailing) {
                                    if busy {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.orange)
                                            .padding(4)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(busy ? "\(number)번 화구, 사용 중" : "\(number)번 화구")
                    }
                }

                Button("화구 없이 시작") {
                    flow.start(recipe, burner: nil)
                }
                .font(.footnote)
            }
        }
    }
}

/// 목록 줄에 붙는 화구 번호.
struct BurnerBadge: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(.black)
            .frame(minWidth: 18, minHeight: 18)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.white))
            .accessibilityLabel("\(number)번 화구")
    }
}
