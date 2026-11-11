import SwiftUI

@main
struct KitchenTimerWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(RecipeStore.shared)
                .environment(TimerQueue.shared)
                .environment(KitchenPrefs.shared)
                .environment(AddFlow.shared)
                .task {
                    RecipeSync.shared.onReceive = {
                        RecipeStore.shared.recipes = $0
                        // 시리가 새 메뉴 이름을 알아듣도록 문구를 갱신한다.
                        KitchenShortcuts.updateAppShortcutParameters()
                    }
                    RecipeSync.shared.activate()
                    KitchenShortcuts.updateAppShortcutParameters()
                    TimerNotifications.requestAuthorization()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                TimerQueue.shared.tick()
                // 스마트 알람은 앱이 활성일 때만 걸 수 있어서, 보일 때마다 다음 알림에 맞춰 둔다.
                AlarmScheduler.shared.appBecameActive(nextAlert: TimerQueue.shared.nextAlertDate)
            }
        }
    }
}
