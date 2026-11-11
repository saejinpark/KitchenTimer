import Foundation
import OSLog
import WatchKit

private let log = Logger(subsystem: "dev.geppetto.KitchenTimer", category: "alarm")

/// 손목을 내려 앱이 화면에서 사라져도 타이머가 끝나면 확인할 때까지 진동하게 한다.
///
/// 일반 로컬 알림은 한 번만 "톡" 울려서 시끄러운 주방에서는 놓치기 쉽다.
/// 스마트 알람 세션(WKBackgroundModes: alarm)을 다음 알림 시각에 예약해 두면,
/// 그 시각에 앱이 깨어나 `notifyUser`로 반복 진동을 울린다.
///
/// 시뮬레이터에서 확인한 제약과 규칙
/// - 예약은 앱이 활성(active) 상태일 때만 된다. 손목을 내린 뒤(inactive)에는 거부된다.
///   그래서 타이머가 바뀔 때와 앱이 다시 보일 때 미리 걸어 둔다.
/// - 시작된 세션이 진동을 한 번도 울리지 않으면 시스템이 "알람 재생 실패"로 보고
///   앱의 백그라운드 기능을 끄자고 묻는다. 그래서 곧 울릴(2초 이내) 세션은 취소하지 않는다.
/// - 앱을 보고 있을 때 울리면 시스템 알람 화면 대신 목록 맨 위 빨간 줄과 앱 진동이 맡는다.
@MainActor
final class AlarmScheduler: NSObject, WKExtendedRuntimeSessionDelegate {
    static let shared = AlarmScheduler()

    private var session: WKExtendedRuntimeSession?
    private var scheduledDate: Date?
    private var repeats = 0

    /// 앱이 다시 보이면 울리던 진동을 멈추고(앱 안 알림이 이어받음) 다음 알림에 다시 건다.
    func appBecameActive(nextAlert date: Date?) {
        if session?.state == .running { invalidate() }
        update(nextAlert: date)
    }

    /// 다음 알림 시각으로 알람을 건다. 앱이 활성 상태일 때만 가능하다.
    func update(nextAlert date: Date?) {
        guard WKApplication.shared().applicationState == .active else { return }
        if session?.state == .running { return }
        if let current = scheduledDate, current.timeIntervalSinceNow <= 2, current.timeIntervalSinceNow > -5 { return }
        guard date != scheduledDate else { return }

        invalidate()
        guard let date, date.timeIntervalSinceNow > 1 else { return }
        let next = WKExtendedRuntimeSession()
        next.delegate = self
        next.start(at: date)
        session = next
        scheduledDate = date
        log.info("알람 예약: \(date.timeIntervalSinceNow, format: .fixed(precision: 1))초 뒤")
    }

    /// 사용자가 앱 안에서 확인하면 진동을 멈춘다.
    func stopRinging() {
        if session?.state == .running { invalidate() }
    }

    private func invalidate() {
        session?.invalidate()
        session = nil
        scheduledDate = nil
    }

    // MARK: WKExtendedRuntimeSessionDelegate

    nonisolated func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {
        let isActive = MainActor.assumeIsolated { WKApplication.shared().applicationState == .active }
        // repeatHandler가 돌려주는 간격은 0보다 크고 60 이하여야 한다. 0을 주면 멈추는 게 아니라
        // 3초로 바뀌어 계속 울리므로, 그만 울릴 때는 세션을 끝낸다.
        if isActive {
            // 앱을 보고 있으면 진동 한 번만 울리고, 나머지는 목록의 빨간 줄과 앱 진동이 맡는다.
            session.notifyUser(hapticType: .notification) { _ in 60 }
            MainActor.assumeIsolated {
                log.info("알람 울림 (앱 보는 중)")
                TimerQueue.shared.tick()
            }
            // 첫 진동은 비동기로 울린다. 바로 끝내면 시스템이 "한 번도 안 울렸다"고 보고
            // 백그라운드 기능을 끄자고 묻기 때문에 잠깐 기다렸다가 끝내고 다음 알림을 건다.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                if self.session === session { self.invalidate() }
                self.update(nextAlert: TimerQueue.shared.nextAlertDate)
            }
            return
        }
        // 손목을 내린 상태: 2초마다 반복 진동, 30번(1분)이면 세션을 끝낸다.
        session.notifyUser(hapticType: .notification) { hapticType in
            hapticType.pointee = .notification
            return MainActor.assumeIsolated {
                self.repeats += 1
                if self.repeats >= 30 {
                    Task { @MainActor in if self.session === session { self.invalidate() } }
                }
                return 2
            }
        }
        MainActor.assumeIsolated {
            self.repeats = 0
            log.info("알람 울림 (백그라운드)")
            // 깨어난 김에 끝난 타이머를 정리하고 앱 안 알림을 쌓아 둔다.
            TimerQueue.shared.tick()
        }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSession(_ session: WKExtendedRuntimeSession,
                                            didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                            error: Error?) {
        Task { @MainActor in
            if self.session === session {
                self.session = nil
                self.scheduledDate = nil
            }
            log.info("알람 세션 종료: reason=\(reason.rawValue) \(error?.localizedDescription ?? "")")
        }
    }
}
