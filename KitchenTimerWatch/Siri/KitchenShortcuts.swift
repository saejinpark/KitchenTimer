import AppIntents

/// 설정 없이 바로 쓸 수 있는 시리 문구. 앱 이름(주방 타이머)이 반드시 들어가야 한다.
struct KitchenShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecipeTimerIntent(),
            phrases: [
                "\(.applicationName)에서 \(\.$recipe) 시작해",
                "\(.applicationName)에서 \(\.$recipe) 시작",
                "\(.applicationName) \(\.$recipe) 타이머",
                "\(.applicationName)에서 타이머 시작해",
            ],
            shortTitle: "메뉴 시작",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: TimerStatusIntent(),
            phrases: [
                "\(.applicationName) 남은 시간 알려줘",
                "\(.applicationName) 남은 시간",
                "\(.applicationName) 타이머 확인",
            ],
            shortTitle: "남은 시간",
            systemImageName: "hourglass"
        )
        AppShortcut(
            intent: ExtendTimerIntent(),
            phrases: [
                "\(.applicationName)에서 \(\.$recipe) 연장해",
                "\(.applicationName)에서 \(\.$recipe) 1분 더",
            ],
            shortTitle: "연장",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: CancelTimerIntent(),
            phrases: [
                "\(.applicationName)에서 \(\.$recipe) 취소해",
                "\(.applicationName)에서 \(\.$recipe) 꺼",
            ],
            shortTitle: "취소",
            systemImageName: "xmark.circle"
        )
    }
}
