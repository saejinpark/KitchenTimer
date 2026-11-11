import Foundation
import Observation
import WatchKit

/// 워치의 타이머 큐. 추가하면 바로 시작하고, 단계가 끝나면 확인할 때까지 맨 위에 남아 지난 시간을 센다.
@MainActor @Observable
final class TimerQueue {
    static let shared = TimerQueue()

    private(set) var timers: [ActiveTimer] {
        didSet {
            save()
            AlarmScheduler.shared.update(nextAlert: nextAlertDate)
        }
    }

    /// 단계 전환("앞면 끝 → 뒷면")을 잠깐 알리는 띠. 화면을 막지 않고 몇 초 뒤 사라진다.
    private(set) var banner: KitchenAlert?

    /// 화면 갱신용 현재 시각. `tick`이 1초마다 갱신한다.
    private(set) var now = Date()

    private let storageKey = "activeTimers.v2"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([ActiveTimer].self, from: data) {
            timers = ActiveTimer.pruned(saved, at: .now)
        } else {
            timers = []
        }
    }

    /// 손이 필요한 것(다음 단계 확인·완성 확인)이 맨 위, 그 아래는 다음 알림이 빠른 순서.
    var sorted: [ActiveTimer] { ActiveTimer.sortedForDisplay(timers, at: now) }
    var attention: [ActiveTimer] { sorted.filter { $0.needsAttention(at: now) } }
    var running: [ActiveTimer] { sorted.filter { !$0.needsAttention(at: now) } }

    /// 가장 먼저 울릴 시각. 스마트 알람을 이 시각에 맞춘다.
    var nextAlertDate: Date? {
        let date = Date()
        return timers.map { $0.nextAlertDate(at: date) }.filter { $0 > date }.min()
    }

    func timer(_ id: UUID) -> ActiveTimer? {
        timers.first { $0.id == id }
    }

    @discardableResult
    func add(_ recipe: Recipe, burner: Int? = nil) -> ActiveTimer? {
        start(name: recipe.name, symbol: recipe.symbol, tint: recipe.tint, steps: recipe.steps, burner: burner)
    }

    /// 이미 확인해서 큐에 없는 메뉴를 알림의 "1분 더"로 다시 걸 때.
    @discardableResult
    func addExtra(name: String, symbol: String, tint: RecipeTint, minutes: Int) -> ActiveTimer? {
        start(name: name, symbol: symbol, tint: tint, steps: [CookStep(name: "추가 \(minutes)분", seconds: minutes * 60)])
    }

    /// 크라운 조정. 진행 중인 타이머만.
    func adjust(_ id: UUID, by seconds: Int) {
        guard let i = timers.firstIndex(where: { $0.id == id }), !timers[i].needsAttention(at: .now) else { return }
        timers[i].adjustCurrentStep(by: seconds, now: .now)
        TimerNotifications.schedule(timers[i])
    }

    /// "1분 더". 이미 끝난 단계면 지금부터 그만큼 더 익힌다.
    func extend(_ id: UUID, by seconds: Int) {
        guard let i = timers.firstIndex(where: { $0.id == id }) else { return }
        timers[i].extend(by: seconds, now: .now)
        TimerNotifications.schedule(timers[i])
        stopRingingIfAllAcknowledged()
    }

    func cancel(_ id: UUID) {
        guard let timer = timer(id) else { return }
        TimerNotifications.cancel(timer)
        timers.removeAll { $0.id == id }
        stopRingingIfAllAcknowledged()
    }

    /// 손이 필요한 줄을 눌렀을 때: 단계 사이면 다음 단계를 지금부터 세고, 완성이면 큐에서 뺀다.
    func acknowledge(_ id: UUID) {
        guard let timer = timer(id) else { return }
        if timer.isWaitingToAdvance(at: .now) {
            advance(id)
        } else {
            cancel(id)
        }
    }

    /// 뒤집기 등 손을 쓴 뒤 다음 단계를 지금부터 센다.
    func advance(_ id: UUID) {
        guard let i = timers.firstIndex(where: { $0.id == id }) else { return }
        timers[i].advance(now: .now)
        TimerNotifications.schedule(timers[i])
        stopRingingIfAllAcknowledged()
    }

    func clearBanner(_ id: KitchenAlert.ID) {
        if banner?.id == id { banner = nil }
    }

    /// 1초마다: 단계 끝 띠를 띄우고, 손이 필요한 타이머는 박자에 맞춰 진동한다.
    func tick(now date: Date = .now) {
        let previous = now
        now = date

        if let step = KitchenAlert.events(for: timers, from: previous, to: date)
            .last(where: { $0.kind != .done }) {
            banner = step
            WKInterfaceDevice.current().play(.directionUp)
        }

        let reminderDue = timers.contains {
            OvertimeReminder.isDue(from: previous.timeIntervalSince($0.attentionDate),
                                   to: date.timeIntervalSince($0.attentionDate))
        }
        if reminderDue {
            WKInterfaceDevice.current().play(.notification)
        }

        let kept = ActiveTimer.pruned(timers, at: date)
        if kept.count != timers.count { timers = kept }
    }

    private func stopRingingIfAllAcknowledged() {
        if attention.isEmpty { AlarmScheduler.shared.stopRinging() }
    }

    private func start(name: String, symbol: String, tint: RecipeTint, steps: [CookStep],
                       burner: Int? = nil) -> ActiveTimer? {
        let steps = steps.filter { $0.seconds > 0 }
        guard !steps.isEmpty else { return nil }
        let ordinal = burner == nil ? ActiveTimer.nextOrdinal(for: name, among: timers) : 1
        let timer = ActiveTimer(recipeName: name, symbol: symbol, tint: tint, steps: steps, startDate: .now,
                                ordinal: ordinal, burner: burner)
        timers.append(timer)
        TimerNotifications.schedule(timer)
        return timer
    }

    private func save() {
        if let data = try? JSONEncoder().encode(timers) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
