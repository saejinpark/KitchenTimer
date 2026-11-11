import Foundation
import Testing

/// 주방에서 실제로 생길 상황을 기준으로 타이머 계산을 검증한다.
/// Shared 폴더를 직접 컴파일하므로 앱 실행 없이 돈다.
@Suite("타이머 계산")
struct TimerModelTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func steak(start: Date? = nil) -> ActiveTimer {
        ActiveTimer(recipeName: "스테이크", symbol: "frying.pan.fill", tint: .red, steps: [
            CookStep(name: "앞면", seconds: 120),
            CookStep(name: "뒷면", seconds: 180),
            CookStep(name: "레스팅", seconds: 300),
        ], startDate: start ?? t0)
    }

    func single(_ name: String, seconds: Int, start: Date, ordinal: Int = 1) -> ActiveTimer {
        ActiveTimer(recipeName: name, symbol: "fork.knife", tint: .orange,
                    steps: [CookStep(name: "조리", seconds: seconds)], startDate: start, ordinal: ordinal)
    }

    @Test("단계 끝 시각은 앞 단계들의 합")
    func stepEndDates() {
        let s = steak()
        #expect(s.stepEndDate(0) == t0 + 120)
        #expect(s.stepEndDate(1) == t0 + 300)
        #expect(s.endDate == t0 + 600)
    }

    @Test("지금 진행 중인 단계와 다음 알림 시각")
    func currentStep() {
        let s = steak()
        #expect(s.currentStepIndex(at: t0) == 0)
        #expect(s.currentStepIndex(at: t0 + 119) == 0)
        #expect(s.currentStepIndex(at: t0 + 120) == nil) // 앞면 끝: 뒤집고 확인할 때까지 대기
        #expect(s.isWaitingToAdvance(at: t0 + 120))
        #expect(s.nextAlertDate(at: t0 + 60) == t0 + 120)
    }

    @Test("링은 현재 단계 기준으로 줄어든다")
    func remainingFraction() {
        let s = steak()
        #expect(s.remainingFraction(at: t0) == 1)
        #expect(abs(s.remainingFraction(at: t0 + 60) - 0.5) < 0.0001)
        #expect(s.remainingFraction(at: t0 + 120) == 0) // 확인 대기 중엔 링이 비어 있다
        #expect(s.remainingFraction(at: t0 + 700) == 0)
    }

    @Test("덜 익었을 때 +1분: 현재 단계만 늘고 뒤 단계는 밀린다")
    func extendShiftsLaterSteps() {
        var s = steak()
        s.adjustCurrentStep(by: 60, now: t0 + 100)
        #expect(s.steps[0].seconds == 180)
        #expect(s.steps[1].seconds == 180)
        #expect(s.endDate == t0 + 660)
    }

    @Test("크라운을 너무 많이 돌려도 최소 5초는 남는다")
    func shortenKeepsFiveSeconds() {
        var s = steak()
        s.adjustCurrentStep(by: -3600, now: t0 + 100)
        #expect(s.stepEndDate(0) == t0 + 105)
    }

    @Test("이미 끝난 타이머는 조정해도 그대로")
    func adjustFinished() {
        var s = steak()
        s.adjustCurrentStep(by: 60, now: t0 + 999)
        #expect(s.endDate == t0 + 600)
    }

    @Test("라면 두 개: 두 번째는 '라면 2', 하나 끝나면 번호를 다시 쓴다")
    func ordinals() {
        let a = single("라면", seconds: 240, start: t0)
        #expect(ActiveTimer.nextOrdinal(for: "라면", among: []) == 1)
        #expect(ActiveTimer.nextOrdinal(for: "라면", among: [a]) == 2)
        let b = single("라면", seconds: 240, start: t0, ordinal: 2)
        #expect(b.displayName == "라면 2")
        #expect(ActiveTimer.nextOrdinal(for: "라면", among: [b]) == 1)
        #expect(ActiveTimer.nextOrdinal(for: "파스타", among: [a, b]) == 1)
    }

    @Test("목록은 다음 알림이 빠른 순서")
    func sorting() {
        let pasta = single("파스타", seconds: 540, start: t0)
        let s = steak(start: t0 + 30) // 앞면이 t0+150에 끝남
        let sorted = ActiveTimer.sortedForDisplay([pasta, s], at: t0 + 60)
        #expect(sorted.map(\.recipeName) == ["스테이크", "파스타"])
    }
}

@Suite("식당 피크 타임")
struct RushHourTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func steak() -> ActiveTimer {
        ActiveTimer(recipeName: "스테이크", symbol: "frying.pan.fill", tint: .red, steps: [
            CookStep(name: "앞면", seconds: 120), CookStep(name: "뒷면", seconds: 180),
        ], startDate: t0)
    }

    func single(_ name: String, seconds: Int, start: Date) -> ActiveTimer {
        ActiveTimer(recipeName: name, symbol: "fork.knife", tint: .orange,
                    steps: [CookStep(name: "조리", seconds: seconds)], startDate: start)
    }

    @Test("끝난 타이머는 사라지지 않고 시간 초과를 센다")
    func overtime() {
        let ramen = single("라면", seconds: 240, start: t0)
        #expect(!ramen.isFinished(at: t0 + 239))
        #expect(ramen.isFinished(at: t0 + 240))
        #expect(ramen.overtime(at: t0 + 200) == 0)
        #expect(ramen.overtime(at: t0 + 285) == 45)
    }

    @Test("끝난 것(오래 지난 것부터)이 맨 위, 그 아래는 급한 순")
    func finishedPinnedOnTop() {
        let a = single("라면", seconds: 60, start: t0)       // t0+60 끝
        let b = single("파스타", seconds: 30, start: t0)     // t0+30 끝 (더 오래 지남)
        let c = single("계란", seconds: 400, start: t0)
        let d = single("수육", seconds: 100, start: t0)
        let order = ActiveTimer.sortedForDisplay([a, c, d, b], at: t0 + 90).map(\.recipeName)
        #expect(order == ["파스타", "라면", "수육", "계란"])
    }

    @Test("긴급도: 30초 이하 남으면 주의, 끝나면 완성")
    func urgency() {
        let ramen = single("라면", seconds: 240, start: t0)
        #expect(ramen.urgency(at: t0 + 100) == .normal)
        #expect(ramen.urgency(at: t0 + 210) == .soon)
        #expect(ramen.urgency(at: t0 + 240) == .done)
    }

    @Test("단계가 곧 끝나도 주의 (스테이크 뒤집기 직전)")
    func urgencyPerStep() {
        let steak = ActiveTimer(recipeName: "스테이크", symbol: "frying.pan.fill", tint: .red, steps: [
            CookStep(name: "앞면", seconds: 120), CookStep(name: "뒷면", seconds: 180),
        ], startDate: t0)
        #expect(steak.urgency(at: t0 + 100) == .soon)
        #expect(steak.urgency(at: t0 + 130) == .done)   // 뒤집으라고 기다리는 중
        var flipped = steak
        flipped.advance(now: t0 + 125)
        #expect(flipped.urgency(at: t0 + 130) == .normal)
    }

    @Test("끝난 뒤 '1분 더'는 지금부터 1분")
    func extendAfterFinished() {
        var ramen = single("라면", seconds: 240, start: t0)
        ramen.extend(by: 60, now: t0 + 270) // 30초 지나서 확인
        #expect(!ramen.isFinished(at: t0 + 270))
        #expect(ramen.endDate == t0 + 330)
        #expect(ramen.steps.count == 1)
    }

    @Test("진행 중 '1분 더'는 현재 단계만 늘린다")
    func extendWhileRunning() {
        var ramen = single("라면", seconds: 240, start: t0)
        ramen.extend(by: 60, now: t0 + 100)
        #expect(ramen.endDate == t0 + 300)
        #expect(ramen.steps.count == 1)
    }

    @Test("30분 넘게 확인 안 한 타이머는 정리")
    func retention() {
        let old = single("라면", seconds: 60, start: t0)
        let fresh = single("파스타", seconds: 60, start: t0 + 1700)
        let kept = ActiveTimer.pruned([old, fresh], at: t0 + 60 + 30 * 60)
        #expect(kept.map(\.recipeName) == ["파스타"])
    }

    @Test("진동 박자: 끝난 순간 0·2·4초, 그 뒤 30초마다")
    func reminderBeats() {
        var beats: [Int] = []
        var previous: TimeInterval = -1
        for second in 0...95 {
            let current = TimeInterval(second)
            if OvertimeReminder.isDue(from: previous, to: current) { beats.append(second) }
            previous = current
        }
        #expect(beats == [0, 2, 4, 30, 60, 90])
    }

    @Test("확인을 미루다 앱을 다시 열면 진동은 한 번만")
    func reminderAfterGap() {
        #expect(OvertimeReminder.isDue(from: 5, to: 125))
        #expect(!OvertimeReminder.isDue(from: 125, to: 126))
        #expect(!OvertimeReminder.isDue(from: -10, to: -5)) // 아직 안 끝남
    }

    @Test("한 시간 넘는 조리(수육·곰탕)도 시계 형식으로 표시")
    func formatting() {
        #expect(formatClock(59) == "0:59")
        #expect(formatClock(540) == "9:00")
        #expect(formatClock(5400) == "1:30:00")
        #expect(formatDuration(45) == "45초")
        #expect(formatDuration(240) == "4분")
        #expect(formatDuration(90) == "1분 30초")
    }

    @Test("이전 버전(이모지) 메뉴 데이터도 읽힌다")
    func legacyRecipeDecoding() throws {
        let json = #"[{"id":"11111111-1111-1111-1111-111111111111","name":"라면","emoji":"🍜","steps":[{"id":"22222222-2222-2222-2222-222222222222","name":"면","seconds":240}]}]"#
        let recipes = try JSONDecoder().decode([Recipe].self, from: Data(json.utf8))
        #expect(recipes.first?.symbol == "fork.knife")
        #expect(recipes.first?.tint == .orange)
        #expect(recipes.first?.totalSeconds == 240)
    }

    @Test("이전 버전 타이머 데이터(번호 없음)도 읽힌다")
    func legacyTimerDecoding() throws {
        var data = try JSONEncoder().encode([steak()])
        var obj = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        obj[0].removeValue(forKey: "ordinal")
        data = try JSONSerialization.data(withJSONObject: obj)
        let timers = try JSONDecoder().decode([ActiveTimer].self, from: data)
        #expect(timers.first?.ordinal == 1)
    }

    @Test("시리: 띄어쓰기와 대소문자는 무시")
    func nameMatching() {
        #expect(normalizedMenuName("반숙 계란") == normalizedMenuName("반숙계란"))
        #expect(normalizedMenuName("Pasta") == normalizedMenuName("pasta"))
    }
}

@Suite("앱 안 알림 감지")
struct KitchenAlertTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func steak() -> ActiveTimer {
        ActiveTimer(recipeName: "스테이크", symbol: "frying.pan.fill", tint: .red, steps: [
            CookStep(name: "앞면", seconds: 120),
            CookStep(name: "뒷면", seconds: 180),
        ], startDate: t0)
    }

    @Test("단계가 끝나면 다음 단계를 알려준다")
    func stepAlert() {
        let alerts = KitchenAlert.events(for: [steak()], from: t0 + 119, to: t0 + 120)
        #expect(alerts.count == 1)
        #expect(alerts.first?.kind == .step(finished: "앞면", next: "뒷면", nextSeconds: 180))
    }

    @Test("뒤집고 확인한 뒤 마지막 단계가 끝나면 완성 알림")
    func doneAlert() {
        var s = steak()
        s.advance(now: t0 + 130) // 10초 늦게 뒤집음 → 뒷면은 t0+310에 끝
        #expect(KitchenAlert.events(for: [s], from: t0 + 299, to: t0 + 300).isEmpty)
        #expect(KitchenAlert.events(for: [s], from: t0 + 309, to: t0 + 310).map(\.kind) == [.done])
    }

    @Test("1초마다 확인해도 같은 알림이 두 번 뜨지 않는다")
    func noDuplicates() {
        var s = steak()
        var all: [KitchenAlert] = []
        var previous = t0
        for second in 1...320 {
            let now = t0 + TimeInterval(second)
            if second == 125 { s.advance(now: now) }
            all += KitchenAlert.events(for: [s], from: previous, to: now)
            previous = now
        }
        #expect(all.map(\.kind) == [.step(finished: "앞면", next: "뒷면", nextSeconds: 180), .done])
    }

    @Test("워치를 한참 안 보다가 열면 지나간 알림은 다시 띄우지 않는다")
    func staleAlertsDropped() {
        let alerts = KitchenAlert.events(for: [steak()], from: t0, to: t0 + 1000)
        #expect(alerts.isEmpty)
    }

    @Test("동시에 끝난 두 메뉴는 끝난 순서대로 둘 다 뜬다")
    func simultaneous() {
        let ramen = ActiveTimer(recipeName: "라면", symbol: "fork.knife", tint: .orange,
                                steps: [CookStep(name: "면", seconds: 120)], startDate: t0 + 1, ordinal: 2)
        let alerts = KitchenAlert.events(for: [ramen, steak()], from: t0 + 119, to: t0 + 121)
        #expect(alerts.map(\.displayName) == ["스테이크", "라면 2"])
    }
}

@Suite("화구 번호와 빠른 추가")
struct BurnerAndQuickAddTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func ramen(burner: Int? = nil, ordinal: Int = 1) -> ActiveTimer {
        ActiveTimer(recipeName: "라면", symbol: "fork.knife", tint: .orange,
                    steps: [CookStep(name: "면", seconds: 240)], startDate: t0, ordinal: ordinal, burner: burner)
    }

    func recipe(_ name: String) -> Recipe {
        Recipe(name: name, symbol: "fork.knife", tint: .orange, steps: [CookStep(name: "조리", seconds: 60)])
    }

    @Test("화구가 있으면 '3번 라면', 목록 줄에는 메뉴 이름만")
    func burnerNames() {
        let r = ramen(burner: 3)
        #expect(r.displayName == "3번 라면")
        #expect(r.rowName == "라면")
        #expect(ramen(ordinal: 2).displayName == "라면 2")
        #expect(ramen(ordinal: 2).rowName == "라면 2")
    }

    @Test("화구를 지정한 라면은 '라면 2' 번호를 차지하지 않는다")
    func burnerSkipsOrdinal() {
        let onBurner = ramen(burner: 1)
        #expect(ActiveTimer.nextOrdinal(for: "라면", among: [onBurner]) == 1)
        #expect(ActiveTimer.nextOrdinal(for: "라면", among: [onBurner, ramen()]) == 2)
    }

    @Test("확인 전인 완성 타이머의 화구도 사용 중")
    func occupied() {
        let done = ActiveTimer(recipeName: "파스타", symbol: "fork.knife", tint: .yellow,
                               steps: [CookStep(name: "면", seconds: 10)], startDate: t0 - 100, burner: 2)
        #expect(ActiveTimer.occupiedBurners([ramen(burner: 5), done, ramen()]) == [2, 5])
    }

    @Test("이전 버전 타이머(화구 없음)도 읽힌다")
    func legacyBurner() throws {
        var obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode([ramen(burner: 4)])) as! [[String: Any]]
        obj[0].removeValue(forKey: "burner")
        let timers = try JSONDecoder().decode([ActiveTimer].self, from: JSONSerialization.data(withJSONObject: obj))
        #expect(timers.first?.burner == nil)
    }

    @Test("많이 쓴 메뉴가 위로, 같으면 폰에서 정한 순서")
    func ranking() {
        let a = recipe("라면"), b = recipe("파스타"), c = recipe("계란")
        var usage = RecipeUsage()
        usage.record(c); usage.record(c); usage.record(b)
        #expect(usage.ranked([a, b, c]).map(\.name) == ["계란", "파스타", "라면"])
        #expect(RecipeUsage().ranked([a, b, c]).map(\.name) == ["라면", "파스타", "계란"])
    }

    @Test("빠른 추가: 써 본 메뉴만 최대 4개, '하나 더'는 마지막 메뉴")
    func favoritesAndLast() {
        let menus = (1...6).map { recipe("메뉴\($0)") }
        var usage = RecipeUsage()
        for m in menus.prefix(5) { usage.record(m) }
        usage.record(menus[1])
        #expect(usage.favorites(menus).count == 4)
        #expect(usage.favorites(menus).first?.name == "메뉴2")
        #expect(usage.last(in: menus)?.name == "메뉴2")
        #expect(RecipeUsage().favorites(menus).isEmpty)
    }

    @Test("폰에서 지운 메뉴는 '하나 더'에 안 나온다")
    func lastDeleted() {
        let gone = recipe("단종")
        var usage = RecipeUsage()
        usage.record(gone)
        #expect(usage.last(in: [recipe("라면")]) == nil)
    }
}

private extension RecipeUsage {
    mutating func record(_ recipe: Recipe) { record(recipe.id) }
}


@Suite("단계 사이 확인")
struct StepConfirmTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func steak() -> ActiveTimer {
        ActiveTimer(recipeName: "스테이크", symbol: "frying.pan.fill", tint: .red, steps: [
            CookStep(name: "앞면", seconds: 120),
            CookStep(name: "뒷면", seconds: 180),
        ], startDate: t0)
    }

    @Test("앞면이 끝나면 뒷면은 저절로 시작하지 않고 기다린다")
    func waitsAfterStep() {
        let s = steak()
        #expect(s.isWaitingToAdvance(at: t0 + 200))
        #expect(!s.isFinished(at: t0 + 1000))
        #expect(s.needsAttention(at: t0 + 200))
        #expect(s.overtime(at: t0 + 150) == 30) // 앞면이 30초째 더 익는 중
    }

    @Test("뒤집고 확인한 순간부터 뒷면 3분을 센다")
    func advanceStartsNow() {
        var s = steak()
        s.advance(now: t0 + 150) // 30초 늦게 뒤집음
        #expect(s.currentStepIndex(at: t0 + 150) == 1)
        #expect(s.stepEndDate(1) == t0 + 330)
        #expect(s.isFinished(at: t0 + 330))
        #expect(!s.isWaitingToAdvance(at: t0 + 330))
    }

    @Test("아직 시간이 남았는데 확인해도 넘어가지 않는다")
    func advanceTooEarly() {
        var s = steak()
        s.advance(now: t0 + 60)
        #expect(s.startedStep == 0)
    }

    @Test("뒤집기 전 '1분 더'는 앞면을 지금부터 1분 더 익힌다")
    func extendWhileWaiting() {
        var s = steak()
        s.extend(by: 60, now: t0 + 150)
        #expect(s.currentStepIndex(at: t0 + 150) == 0)
        #expect(s.stepEndDate(0) == t0 + 210)
    }

    @Test("대기 중인 단계도 30초마다 다시 진동할 박자가 온다")
    func reminderWhileWaiting() {
        let s = steak()
        let over = { (now: Date) in now.timeIntervalSince(s.attentionDate) }
        #expect(OvertimeReminder.isDue(from: over(t0 + 119), to: over(t0 + 120)))
        #expect(OvertimeReminder.isDue(from: over(t0 + 149), to: over(t0 + 150)))
    }

    @Test("확인 대기는 완성보다 먼저 일어났으면 위로 정렬")
    func sorting() {
        let waiting = steak()                                            // t0+120부터 대기
        let done = ActiveTimer(recipeName: "라면", symbol: "fork.knife", tint: .orange,
                               steps: [CookStep(name: "면", seconds: 150)], startDate: t0) // t0+150 완성
        let order = ActiveTimer.sortedForDisplay([done, waiting], at: t0 + 160).map(\.recipeName)
        #expect(order == ["스테이크", "라면"])
    }

    @Test("이전 버전 타이머(단계 시작 기록 없음)도 읽힌다")
    func legacy() throws {
        var obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode([steak()])) as! [[String: Any]]
        obj[0].removeValue(forKey: "laterStarts")
        let timers = try JSONDecoder().decode([ActiveTimer].self, from: JSONSerialization.data(withJSONObject: obj))
        #expect(timers.first?.startedStep == 0)
    }
}
