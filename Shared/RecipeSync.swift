import Foundation
import OSLog
import WatchConnectivity

private let log = Logger(subsystem: "dev.geppetto.KitchenTimer", category: "sync")

/// 폰 → 워치 메뉴 동기화. applicationContext는 마지막 값만 남으므로 목록 전체를 매번 보낸다.
@MainActor
final class RecipeSync: NSObject, WCSessionDelegate {
    static let shared = RecipeSync()

    /// 워치에서 새 메뉴 목록을 받았을 때 호출된다.
    var onReceive: (([Recipe]) -> Void)?

    private nonisolated static let contextKey = "recipes"
    private var pending: [Recipe]?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    #if os(iOS)
    func send(_ recipes: [Recipe]) {
        pending = recipes
        flush()
    }

    private func flush() {
        let session = WCSession.default
        guard let recipes = pending else { return }
        // isWatchAppInstalled는 설치 직후 한동안 false로 남는 경우가 있어 조건에서 뺀다.
        // 정말 설치되지 않았다면 updateApplicationContext가 에러를 던지고 pending이 남는다.
        guard session.activationState == .activated, session.isPaired else {
            log.info("동기화 대기: activated=\(session.activationState == .activated) paired=\(session.isPaired) installed=\(session.isWatchAppInstalled)")
            return
        }
        guard let data = try? JSONEncoder().encode(recipes) else { return }
        do {
            try session.updateApplicationContext([Self.contextKey: data])
            pending = nil
            log.info("메뉴 \(recipes.count)개 동기화")
        } catch {
            log.error("메뉴 동기화 실패: \(error.localizedDescription)")
        }
    }
    #endif

    private nonisolated static func decode(_ context: [String: Any]) -> [Recipe]? {
        guard let data = context[contextKey] as? Data else { return nil }
        return try? JSONDecoder().decode([Recipe].self, from: data)
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        #if os(iOS)
        Task { @MainActor in self.flush() }
        #else
        if let recipes = Self.decode(session.receivedApplicationContext) {
            Task { @MainActor in self.onReceive?(recipes) }
        }
        #endif
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        if let recipes = Self.decode(context) {
            Task { @MainActor in self.onReceive?(recipes) }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.flush() }
    }
    #endif
}
