import Foundation
import UserNotifications
import WatchKit

/// 지금 세고 있는 단계가 끝나는 시각에 로컬 알림을 예약한다.
/// 다음 단계는 사용자가 확인해야 시작하므로, 확인할 때마다 다시 예약한다.
/// 앱이 꺼져 있어도 시스템이 알림을 띄우므로 이게 실제 "타이머 종료" 신호다.
enum TimerNotifications {
    static let doneCategory = "TIMER_DONE"
    static let stepCategory = "TIMER_STEP"
    static let extendAction = "EXTEND_1_MIN"
    static let advanceAction = "ADVANCE_STEP"

    static func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationHandler.shared
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: doneCategory,
                actions: [
                    UNNotificationAction(identifier: extendAction, title: "1분 더",
                                         icon: UNNotificationActionIcon(systemImageName: "goforward.60")),
                ],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: stepCategory,
                actions: [
                    UNNotificationAction(identifier: advanceAction, title: "다음 단계 시작",
                                         icon: UNNotificationActionIcon(systemImageName: "arrow.right.circle.fill")),
                    UNNotificationAction(identifier: extendAction, title: "1분 더",
                                         icon: UNNotificationActionIcon(systemImageName: "goforward.60")),
                ],
                intentIdentifiers: []
            ),
        ])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    static func schedule(_ timer: ActiveTimer) {
        cancel(timer)
        let now = Date()
        let center = UNUserNotificationCenter.current()

        let i = timer.startedStep
        let step = timer.steps[i]
        let interval = timer.stepEndDate(i).timeIntervalSince(now)
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = timer.displayName
        content.threadIdentifier = timer.id.uuidString
        content.sound = .default
        // 집중 모드를 뚫으려면 Time Sensitive Notifications 기능(entitlement)을 켜야 한다.
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["id": timer.id.uuidString, "name": timer.recipeName,
                            "symbol": timer.symbol, "tint": timer.tint.rawValue]

        if i + 1 < timer.steps.count {
            let next = timer.steps[i + 1]
            content.subtitle = "\(step.name) 끝"
            content.body = "확인하면 \(next.name) \(formatDuration(next.seconds)) 시작"
            content.categoryIdentifier = stepCategory
        } else {
            content.subtitle = "완성"
            content.body = "불을 끄고 확인하세요"
            content.categoryIdentifier = doneCategory
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier(timer, i), content: content, trigger: trigger))
    }

    static func cancel(_ timer: ActiveTimer) {
        let ids = timer.steps.indices.map { identifier(timer, $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func identifier(_ timer: ActiveTimer, _ step: Int) -> String {
        "\(timer.id.uuidString)#\(step)"
    }
}

final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    /// 앱을 보고 있을 때는 시스템 배너 대신 앱 안의 단계 띠와 목록 맨 위 빨간 줄이 맡는다.
    /// 손목을 내려 화면이 꺼진 상태(inactive)에서도 이 메서드가 불릴 수 있는데,
    /// 그때는 앱 화면 갱신이 느려지므로 시스템 배너와 소리를 그대로 띄운다.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let isActive = await MainActor.run { WKApplication.shared().applicationState == .active }
        return isActive ? [.list] : [.banner, .sound, .list]
    }

    /// 알림 버튼. "다음 단계 시작"은 지금부터 다음 단계를 세고,
    /// "1분 더"는 큐에 남아 있는 그 타이머를 이어서 돌린다(이미 확인해서 없으면 1분짜리를 새로 건다).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        if response.actionIdentifier == TimerNotifications.advanceAction,
           let id = (info["id"] as? String).flatMap(UUID.init(uuidString:)) {
            await MainActor.run { TimerQueue.shared.advance(id) }
            return
        }
        guard response.actionIdentifier == TimerNotifications.extendAction else { return }
        if let id = (info["id"] as? String).flatMap(UUID.init(uuidString:)),
           await MainActor.run(body: { TimerQueue.shared.timer(id) != nil }) {
            await MainActor.run { TimerQueue.shared.extend(id, by: 60) }
            return
        }
        guard let name = info["name"] as? String,
              let symbol = info["symbol"] as? String,
              let tint = (info["tint"] as? String).flatMap(RecipeTint.init) else { return }
        await MainActor.run {
            _ = TimerQueue.shared.addExtra(name: name, symbol: symbol, tint: tint, minutes: 1)
        }
    }
}
