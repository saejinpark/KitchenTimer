import AppIntents
import Foundation

/// "주방 타이머에서 파스타 시작해"
struct StartRecipeTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "메뉴 타이머 시작"
    static let description = IntentDescription("등록한 메뉴의 타이머를 큐에 추가하고 바로 시작합니다.")

    @Parameter(title: "메뉴", requestValueDialog: "어떤 메뉴를 시작할까요?")
    var recipe: RecipeEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let menu = RecipeStore.shared.recipes.first(where: { $0.id == recipe.id }),
              TimerQueue.shared.add(menu) != nil else {
            return .result(dialog: "\(recipe.name) 메뉴를 시작할 수 없어요.")
        }
        let first = menu.steps.first { $0.seconds > 0 }
        if menu.steps.count > 1, let first {
            return .result(dialog: "\(menu.name) 시작할게요. 먼저 \(first.name) \(formatDuration(first.seconds))이에요.")
        }
        return .result(dialog: "\(menu.name) \(formatDuration(menu.totalSeconds)) 타이머 시작할게요.")
    }
}

/// "주방 타이머 남은 시간 알려줘"
struct TimerStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "남은 타이머 확인"
    static let description = IntentDescription("진행 중인 타이머와 남은 시간을 알려줍니다.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let queue = TimerQueue.shared
        queue.tick()
        let timers = queue.sorted
        guard !timers.isEmpty else {
            return .result(dialog: "진행 중인 타이머가 없어요.")
        }
        let parts = timers.map { describe($0, now: queue.now) }
        return .result(dialog: "\(parts.joined(separator: ", "))이에요.")
    }

    private func describe(_ timer: ActiveTimer, now: Date) -> String {
        guard let i = timer.currentStepIndex(at: now) else {
            let over = formatDuration(Int(timer.overtime(at: now)))
            if timer.isWaitingToAdvance(at: now) {
                return "\(timer.displayName) \(timer.steps[timer.startedStep].name) 끝, \(over) 지남"
            }
            return "\(timer.displayName) 완성, \(over) 지남"
        }
        let label = timer.steps.count > 1 ? "\(timer.displayName) \(timer.steps[i].name)" : timer.displayName
        return "\(label) \(remaining(until: timer.stepEndDate(i), now: now)) 남음"
    }
}

/// "주방 타이머에서 파스타 연장해"
struct ExtendTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "타이머 연장"
    static let description = IntentDescription("진행 중인 메뉴 타이머의 현재 단계를 늘립니다.")

    @Parameter(title: "메뉴", requestValueDialog: "어떤 메뉴를 연장할까요?")
    var recipe: RecipeEntity

    @Parameter(title: "분", default: 1, inclusiveRange: (1, 30))
    var minutes: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let queue = TimerQueue.shared
        queue.tick()
        guard let timer = runningTimer(named: recipe.name) else {
            return .result(dialog: "진행 중인 \(recipe.name) 타이머가 없어요.")
        }
        queue.extend(timer.id, by: minutes * 60)
        let updated = queue.timer(timer.id) ?? timer
        let end = updated.nextAlertDate(at: .now)
        return .result(dialog: "\(timer.displayName) \(minutes)분 늘렸어요. \(remaining(until: end, now: .now)) 남았어요.")
    }
}

/// "주방 타이머에서 파스타 취소해"
struct CancelTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "타이머 취소"
    static let description = IntentDescription("진행 중인 메뉴 타이머를 취소합니다.")

    @Parameter(title: "메뉴", requestValueDialog: "어떤 메뉴를 취소할까요?")
    var recipe: RecipeEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        TimerQueue.shared.tick()
        guard let timer = runningTimer(named: recipe.name) else {
            return .result(dialog: "진행 중인 \(recipe.name) 타이머가 없어요.")
        }
        TimerQueue.shared.cancel(timer.id)
        return .result(dialog: "\(timer.displayName) 타이머를 취소했어요.")
    }
}

/// 같은 메뉴가 여러 개 돌고 있으면 가장 먼저 울릴 타이머를 고른다.
@MainActor
private func runningTimer(named name: String) -> ActiveTimer? {
    TimerQueue.shared.sorted.first { normalizedMenuName($0.recipeName) == normalizedMenuName(name) }
}

private func remaining(until end: Date, now: Date) -> String {
    formatDuration(max(0, Int(end.timeIntervalSince(now).rounded(.up))))
}
