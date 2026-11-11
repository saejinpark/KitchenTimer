import Foundation

/// 진행 중인 타이머 하나. 남은 시간을 직접 세지 않고 단계 시작 시각과 길이로 계산하므로
/// 앱이 백그라운드에서 멈춰 있어도 다시 열면 정확하다.
///
/// 단계가 여러 개면 한 단계가 끝난 뒤 저절로 다음 단계로 넘어가지 않는다.
/// 고기를 뒤집는 등 손이 가야 하므로, 사용자가 확인한 순간부터 다음 단계를 센다.
/// 확인을 기다리는 동안은 끝난 뒤 지난 시간을 센다(그만큼 더 익고 있다).
struct ActiveTimer: Codable, Identifiable, Hashable {
    var id = UUID()
    var recipeName: String
    var symbol: String
    var tint: RecipeTint
    var steps: [CookStep]
    /// 첫 단계를 시작한 시각.
    var startDate: Date
    /// 두 번째 단계부터, 사용자가 확인해 시작한 시각.
    var laterStarts: [Date] = []
    /// 같은 메뉴를 여러 개 돌릴 때 구분하는 번호 (라면, 라면 2, …). 화구 번호가 있으면 쓰지 않는다.
    var ordinal = 1
    /// 올려 둔 화구 번호. 식당에서는 메뉴 이름보다 "어느 냄비인지"가 중요하다.
    var burner: Int?

    init(id: UUID = UUID(), recipeName: String, symbol: String, tint: RecipeTint,
         steps: [CookStep], startDate: Date, ordinal: Int = 1, burner: Int? = nil) {
        self.id = id
        self.recipeName = recipeName
        self.symbol = symbol
        self.tint = tint
        self.steps = steps
        self.startDate = startDate
        self.ordinal = ordinal
        self.burner = burner
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        recipeName = try c.decode(String.self, forKey: .recipeName)
        symbol = try c.decode(String.self, forKey: .symbol)
        tint = try c.decode(RecipeTint.self, forKey: .tint)
        steps = try c.decode([CookStep].self, forKey: .steps)
        startDate = try c.decode(Date.self, forKey: .startDate)
        laterStarts = try c.decodeIfPresent([Date].self, forKey: .laterStarts) ?? []
        ordinal = try c.decodeIfPresent(Int.self, forKey: .ordinal) ?? 1
        burner = try c.decodeIfPresent(Int.self, forKey: .burner)
    }

    /// 알림·시리에서 부르는 이름: "3번 라면", "라면 2", "라면".
    var displayName: String {
        if let burner { return "\(burner)번 \(recipeName)" }
        return ordinal > 1 ? "\(recipeName) \(ordinal)" : recipeName
    }

    /// 목록 줄에 쓰는 이름. 화구 번호는 따로 배지로 보여 주므로 뺀다.
    var rowName: String { burner == nil ? displayName : recipeName }

    // MARK: 단계

    /// 지금까지 시작한 마지막 단계.
    var startedStep: Int { laterStarts.count }

    private func stepStart(_ index: Int) -> Date {
        index == 0 ? startDate : laterStarts[index - 1]
    }

    /// 단계가 끝나는 시각. 아직 시작 안 한 단계는 "지금 단계 끝에 바로 확인한다면"으로 어림한다.
    func stepEndDate(_ index: Int) -> Date {
        if index <= startedStep {
            return stepStart(index).addingTimeInterval(TimeInterval(steps[index].seconds))
        }
        let rest = steps[(startedStep + 1)...index].reduce(0) { $0 + $1.seconds }
        return stepEndDate(startedStep).addingTimeInterval(TimeInterval(rest))
    }

    /// 다 끝나는 어림 시각.
    var endDate: Date { stepEndDate(steps.count - 1) }

    /// 지금 세고 있는 단계. 끝나서 확인을 기다리거나 완성이면 nil.
    func currentStepIndex(at now: Date) -> Int? {
        stepEndDate(startedStep) > now ? startedStep : nil
    }

    /// 단계 하나가 끝나서 "다음 단계 시작"을 기다리는 중.
    func isWaitingToAdvance(at now: Date) -> Bool {
        startedStep < steps.count - 1 && stepEndDate(startedStep) <= now
    }

    /// 마지막 단계까지 끝남.
    func isFinished(at now: Date) -> Bool {
        startedStep == steps.count - 1 && stepEndDate(startedStep) <= now
    }

    /// 사람 손이 필요한 상태(다음 단계 확인 또는 완성 확인).
    func needsAttention(at now: Date) -> Bool { currentStepIndex(at: now) == nil }

    /// 손이 필요해진 시각 = 지금 단계가 끝난 시각.
    var attentionDate: Date { stepEndDate(startedStep) }

    /// 다음으로 알림이 울릴 시각 (지금 단계의 끝).
    func nextAlertDate(at now: Date) -> Date { attentionDate }

    /// 지금 단계에서 남은 비율 (1 → 0).
    func remainingFraction(at now: Date) -> Double {
        guard let i = currentStepIndex(at: now), steps[i].seconds > 0 else { return 0 }
        return min(1, max(0, stepEndDate(i).timeIntervalSince(now) / Double(steps[i].seconds)))
    }

    /// 확인을 기다리던 다음 단계를 지금부터 센다.
    mutating func advance(now: Date) {
        guard isWaitingToAdvance(at: now) else { return }
        laterStarts.append(now)
    }

    /// 크라운 조정: 세고 있는 단계 길이를 늘리거나 줄인다. 최소 5초는 남긴다.
    mutating func adjustCurrentStep(by delta: Int, now: Date) {
        guard let i = currentStepIndex(at: now) else { return }
        let elapsed = Int(now.timeIntervalSince(stepStart(i)).rounded(.up))
        steps[i].seconds = max(elapsed + 5, steps[i].seconds + delta)
    }

    // MARK: 끝난 뒤

    /// 단계가 끝난 뒤 지난 시간. 세고 있는 중이면 0.
    func overtime(at now: Date) -> TimeInterval {
        needsAttention(at: now) ? now.timeIntervalSince(attentionDate) : 0
    }

    enum Urgency { case normal, soon, done }

    /// 흘끗 봤을 때 읽히는 긴급도. 지금 단계가 30초 이하로 남으면 `soon`, 손이 필요하면 `done`.
    func urgency(at now: Date, soonThreshold: TimeInterval = 30) -> Urgency {
        guard let i = currentStepIndex(at: now) else { return .done }
        return stepEndDate(i).timeIntervalSince(now) <= soonThreshold ? .soon : .normal
    }

    /// "1분 더": 세고 있으면 그 단계를 늘리고, 이미 끝났으면(다음 단계 대기·완성 모두) 지금 단계를
    /// 지금부터 그만큼 더 익힌다.
    mutating func extend(by seconds: Int, now: Date) {
        guard needsAttention(at: now) else {
            adjustCurrentStep(by: seconds, now: now)
            return
        }
        let elapsed = Int(now.timeIntervalSince(stepStart(startedStep)).rounded(.up))
        steps[startedStep].seconds = elapsed + seconds
    }

    /// 확인하지 않은 채 이보다 오래 지난 타이머는 정리한다(앱을 한참 안 열었을 때).
    static let finishedRetention: TimeInterval = 30 * 60

    static func pruned(_ timers: [ActiveTimer], at now: Date) -> [ActiveTimer] {
        timers.filter { $0.overtime(at: now) < finishedRetention }
    }

    // MARK: 목록

    /// 같은 메뉴가 이미 돌고 있으면 비어 있는 가장 작은 번호를 준다.
    static func nextOrdinal(for name: String, among timers: [ActiveTimer]) -> Int {
        let used = Set(timers.filter { $0.recipeName == name && $0.burner == nil }.map(\.ordinal))
        return (1...).first { !used.contains($0) }!
    }

    /// 냄비가 올라가 있는 화구. 끝났어도 확인 전이면 아직 불 위에 있다고 본다.
    static func occupiedBurners(_ timers: [ActiveTimer]) -> Set<Int> {
        Set(timers.compactMap(\.burner))
    }

    /// 손이 필요한 것(오래 기다린 것부터)을 맨 위에, 그 아래는 다음 알림이 빠른 순서.
    static func sortedForDisplay(_ timers: [ActiveTimer], at now: Date) -> [ActiveTimer] {
        let attention = timers.filter { $0.needsAttention(at: now) }.sorted { $0.attentionDate < $1.attentionDate }
        let running = timers.filter { !$0.needsAttention(at: now) }.sorted { $0.attentionDate < $1.attentionDate }
        return attention + running
    }
}

/// 끝났는데 확인하지 않은 타이머의 진동 박자.
/// 끝난 순간 2초 간격으로 3번, 그 뒤로는 확인할 때까지 30초마다 한 번.
enum OvertimeReminder {
    static let burst: [TimeInterval] = [0, 2, 4]
    static let interval: TimeInterval = 30

    /// 시간 초과가 `previous`에서 `current`로 지나는 사이에 진동할 박자가 있었는지.
    static func isDue(from previous: TimeInterval, to current: TimeInterval) -> Bool {
        guard current >= 0, current > previous else { return false }
        if burst.contains(where: { $0 > previous && $0 <= current }) { return true }
        let lastBeat = (current / interval).rounded(.down) * interval
        return lastBeat >= interval && lastBeat > previous
    }
}

/// 앱을 보고 있을 때 감지한 단계 끝이나 완성. 단계 끝은 화면 위 띠로 잠깐 보여준다.
struct KitchenAlert: Identifiable, Equatable {
    enum Kind: Equatable {
        case step(finished: String, next: String, nextSeconds: Int)
        case done
    }

    let id = UUID()
    let recipeName: String
    let displayName: String
    let symbol: String
    let tint: RecipeTint
    let kind: Kind

    /// `previous` 이후 `now`까지 끝난 단계를 알림으로 만든다.
    /// 오래 꺼져 있다가 돌아온 경우 지나간 알림은 이미 시스템 알림으로 받았으므로 버린다.
    static func events(for timers: [ActiveTimer], from previous: Date, to now: Date,
                       staleAfter: TimeInterval = 3) -> [KitchenAlert] {
        var result: [(Date, KitchenAlert)] = []
        for timer in timers {
            let i = timer.startedStep
            let end = timer.stepEndDate(i)
            guard end > previous, end <= now, now.timeIntervalSince(end) < staleAfter else { continue }
            let kind: Kind = i + 1 < timer.steps.count
                ? .step(finished: timer.steps[i].name, next: timer.steps[i + 1].name, nextSeconds: timer.steps[i + 1].seconds)
                : .done
            result.append((end, KitchenAlert(recipeName: timer.recipeName, displayName: timer.displayName,
                                             symbol: timer.symbol, tint: timer.tint, kind: kind)))
        }
        return result.sorted { $0.0 < $1.0 }.map(\.1)
    }
}

/// 시리나 검색에서 "반숙계란"과 "반숙 계란"을 같은 메뉴로 본다.
func normalizedMenuName(_ name: String) -> String {
    name.filter { !$0.isWhitespace }.lowercased()
}
