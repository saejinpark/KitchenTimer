import SwiftUI

/// 단계가 끝났을 때 위에 잠깐 뜨는 띠. 화면을 막지 않고 터치도 가로채지 않으며 4초 뒤 사라진다.
/// 다음 단계는 목록 맨 위 빨간 줄을 누르거나 더블 탭해야 시작된다.
struct StepBanner: View {
    @Environment(TimerQueue.self) private var queue
    let alert: KitchenAlert

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: alert.symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(alert.tint.color))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(alert.displayName) · \(finished) 끝")
                    .font(.footnote.weight(.semibold))
                Text("뒤집고 탭하면 \(next)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(alert.tint.color, lineWidth: 2))
        .padding(.horizontal, 4)
        .allowsHitTesting(false)
        .task(id: alert.id) {
            try? await Task.sleep(for: .seconds(4))
            queue.clearBanner(alert.id)
        }
    }

    private var finished: String {
        if case .step(let finished, _, _) = alert.kind { return finished }
        return ""
    }

    private var next: String {
        if case .step(_, let next, let seconds) = alert.kind { return "\(next) \(formatDuration(seconds))" }
        return ""
    }
}
