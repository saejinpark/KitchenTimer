import SwiftUI
import WatchKit

/// 타이머 하나를 큰 링으로 보여준다. 디지털 크라운으로 10초씩 조정한다.
struct TimerDetailView: View {
    @Environment(TimerQueue.self) private var queue
    @Environment(\.dismiss) private var dismiss
    let timerID: UUID

    @State private var crown = 0.0
    @State private var crownDelta = 0
    @State private var confirmingCancel = false

    var body: some View {
        if let timer = queue.timer(timerID) {
            if let index = timer.currentStepIndex(at: queue.now) {
                content(timer, index: index)
            } else {
                finishedContent(timer)
            }
        } else {
            // 다른 곳(목록, 시리)에서 확인하거나 취소한 경우.
            Color.clear.task { dismiss() }
        }
    }

    /// 보고 있던 단계가 끝나면 그 자리에서 지난 시간을 센다.
    /// 단계 사이면 "다음 단계 시작"(뒤집은 뒤 누름), 완성이면 "확인". 둘 다 더블 탭으로도 된다.
    private func finishedContent(_ timer: ActiveTimer) -> some View {
        let waiting = timer.isWaitingToAdvance(at: queue.now)
        let current = timer.steps[timer.startedStep]
        let next = waiting ? timer.steps[timer.startedStep + 1] : nil
        let tint: Color = waiting ? .orange : .red

        return VStack(spacing: 4) {
            Image(systemName: timer.symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 50, height: 50)
                .background(Circle().fill(.white))
            Text(waiting ? "\(timer.displayName) · \(current.name) 끝" : "\(timer.displayName) 완성")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            OvertimeText(since: timer.attentionDate)
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
            if let next {
                Text("다음: \(next.name) \(formatClock(next.seconds))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .containerBackground(tint.gradient, for: .navigation)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("1분 더", systemImage: "goforward.60") {
                    queue.extend(timerID, by: 60)
                }
                Spacer()
                if waiting {
                    Button("다음 단계 시작", systemImage: "arrow.right") {
                        queue.advance(timerID)
                        WKInterfaceDevice.current().play(.start)
                    }
                    .tint(tint)
                    .handGestureShortcut(.primaryAction)
                } else {
                    Button("확인", systemImage: "checkmark") {
                        queue.acknowledge(timerID)
                        dismiss()
                    }
                    .tint(tint)
                    .handGestureShortcut(.primaryAction)
                }
            }
        }
    }

    private func content(_ timer: ActiveTimer, index: Int) -> some View {
        let tint = timer.tint.color
        return VStack(spacing: 6) {
            ProgressRing(progress: timer.remainingFraction(at: queue.now), tint: tint, lineWidth: 8) {
                VStack(spacing: 0) {
                    Image(systemName: timer.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                    CountdownText(until: timer.stepEndDate(index), now: queue.now)
                        .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(timer.steps.count > 1 ? "\(timer.displayName) · \(timer.steps[index].name)" : timer.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
            }
            .overlay(alignment: .top) {
                if crownDelta != 0 {
                    Text(crownDelta > 0 ? "+\(formatDuration(crownDelta))" : "−\(formatDuration(-crownDelta))")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.thinMaterial, in: Capsule())
                        .offset(y: -6)
                        .transition(.opacity)
                }
            }

            if timer.steps.count > 1 {
                StepDots(count: timer.steps.count, current: index, tint: tint)
            }
        }
        .padding(.horizontal, 8)
        .containerBackground(tint.gradient, for: .navigation)
        .focusable()
        .digitalCrownRotation($crown, from: -3600, through: 3600, by: 10,
                              sensitivity: .low, isContinuous: true, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { old, new in
            let delta = Int((new - old).rounded())
            guard delta != 0 else { return }
            queue.adjust(timerID, by: delta)
            withAnimation { crownDelta += delta }
        }
        .task(id: crownDelta) {
            guard crownDelta != 0 else { return }
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation { crownDelta = 0 }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                // 젖은 손이 스쳐서 꺼지지 않도록 한 번 더 묻는다.
                Button("취소", systemImage: "xmark", role: .destructive) {
                    confirmingCancel = true
                }
                Spacer()
                Button("1분 추가", systemImage: "goforward.60") {
                    queue.extend(timerID, by: 60)
                    WKInterfaceDevice.current().play(.click)
                }
                .tint(tint)
                .handGestureShortcut(.primaryAction)
            }
        }
        .confirmationDialog("\(timer.displayName) 타이머를 끌까요?", isPresented: $confirmingCancel,
                            titleVisibility: .visible) {
            Button("타이머 끄기", role: .destructive) {
                queue.cancel(timerID)
                dismiss()
            }
            Button("계속 조리", role: .cancel) {}
        }
    }
}

/// 단계 진행 표시: 지난 단계는 채워진 막대, 현재 단계는 긴 막대.
private struct StepDots: View {
    let count: Int
    let current: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? tint : tint.opacity(0.25))
                    .frame(width: i == current ? 16 : 6, height: 6)
            }
        }
    }
}
