import SwiftUI

/// 세로 페이지 TabView: 위는 진행 중인 큐, 아래로 넘기면 메뉴 추가.
struct ContentView: View {
    @Environment(TimerQueue.self) private var queue
    @Environment(AddFlow.self) private var flow
    @State private var page = Page.queue

    enum Page { case queue, add }

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                QueueView(onAdd: { page = .add })
                    .tag(Page.queue)
                AddRecipeView()
                    .tag(Page.add)
            }
            .tabViewStyle(.verticalPage)
            // TabView 페이지 안에 두면 NavigationStack이 인식하지 못해 여기에 둔다.
            .navigationDestination(for: UUID.self) { id in
                TimerDetailView(timerID: id)
            }
        }
        // 단계 끝 띠는 화면을 막지 않는다. 확인은 목록 맨 위 빨간 줄이 맡는다.
        .overlay(alignment: .top) {
            if let banner = queue.banner {
                StepBanner(alert: banner)
                    .id(banner.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: queue.banner?.id)
        .sheet(item: Bindable(flow).pendingRecipe) { recipe in
            BurnerPicker(recipe: recipe)
        }
        .onAppear {
            flow.onStarted = { page = .queue }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            queue.tick(now: date)
        }
    }
}

struct QueueView: View {
    @Environment(TimerQueue.self) private var queue
    @Environment(RecipeStore.self) private var store
    @Environment(KitchenPrefs.self) private var prefs
    @Environment(AddFlow.self) private var flow
    @Environment(\.scenePhase) private var scenePhase
    var onAdd: () -> Void

    /// 타이머가 이보다 많으면 한 줄짜리 촘촘한 목록으로 바꾼다.
    private let compactThreshold = 4

    var body: some View {
        Group {
            if queue.timers.isEmpty && prefs.usage.favorites(store.recipes).isEmpty {
                ContentUnavailableView {
                    Label("타이머 없음", systemImage: "timer")
                } description: {
                    if prefs.notificationsOff {
                        Label("알림이 꺼져 있어요", systemImage: "bell.slash.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Text("아래로 넘겨 메뉴를 고르세요")
                    }
                } actions: {
                    Button("메뉴 추가", systemImage: "plus", action: onAdd)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                list
            }
        }
        .task(id: scenePhase) {
            await prefs.refreshNotificationStatus()
        }
        .toolbar {
            // 방금 넣은 메뉴를 한 번 더: 피크 타임에 같은 주문이 연달아 들어올 때.
            if let last = prefs.usage.last(in: store.recipes) {
                ToolbarItem(placement: .topBarLeading) {
                    Button("\(last.name) 하나 더", systemImage: "arrow.counterclockwise") {
                        flow.choose(last)
                    }
                    .tint(last.tint.color)
                }
            }
            if !queue.timers.isEmpty || !prefs.usage.favorites(store.recipes).isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("메뉴 추가", systemImage: "plus", action: onAdd)
                }
            }
        }
    }

    private var list: some View {
        let attention = queue.attention
        let running = queue.running
        let compact = queue.timers.count > compactThreshold
        let blink = Int(queue.now.timeIntervalSinceReferenceDate) % 2 == 0

        return List {
            if prefs.notificationsOff {
                NotificationsOffRow()
            }

            if queue.timers.isEmpty {
                Label("진행 중인 타이머 없음", systemImage: "timer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            if !attention.isEmpty {
                Section {
                    ForEach(Array(attention.enumerated()), id: \.element.id) { index, timer in
                        // 줄 전체가 확인 버튼: 단계 사이면 다음 단계 시작, 완성이면 큐에서 뺀다.
                        // 장갑을 껴도 누르기 쉽고, 맨 위 것은 더블 탭으로도 된다.
                        Button {
                            queue.acknowledge(timer.id)
                        } label: {
                            AttentionRow(timer: timer, now: queue.now, compact: compact)
                        }
                        .handGestureShortcut(.primaryAction, isEnabled: index == 0)
                        .listRowInsets(compact ? Self.compactInsets : nil)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.red.opacity(blink ? 0.55 : 0.3))
                                .animation(.easeInOut(duration: 0.8), value: blink)
                        )
                        .swipeActions {
                            Button("1분 더", systemImage: "goforward.60") {
                                queue.extend(timer.id, by: 60)
                            }
                            .tint(.orange)
                        }
                    }
                } header: {
                    Text("확인 필요 \(attention.count)")
                        .foregroundStyle(.red)
                }
            }

            if !running.isEmpty {
                Section {
                    ForEach(running) { timer in
                        let urgency = timer.urgency(at: queue.now)
                        NavigationLink(value: timer.id) {
                            TimerRow(timer: timer, now: queue.now, compact: compact)
                        }
                        .listRowInsets(compact ? Self.compactInsets : nil)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: compact ? 16 : 22, style: .continuous)
                                .fill(urgency == .soon ? Color.orange.opacity(0.3) : Color.white.opacity(0.1))
                        )
                        .swipeActions {
                            Button("취소", systemImage: "xmark", role: .destructive) {
                                queue.cancel(timer.id)
                            }
                        }
                    }
                } header: {
                    Text("진행 중 \(running.count)")
                }
            }

            QuickAddSection()
        }
        // 워치 목록의 기본 최소 줄 높이가 커서, 촘촘한 목록에선 낮춰야 한 화면에 더 들어간다.
        .environment(\.defaultMinListRowHeight, compact ? 36 : 44)
    }

    private static let compactInsets = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
}

/// 알림이 꺼져 있으면 손목을 내렸을 때 타이머가 끝나도 아무것도 안 뜬다. 그 위험을 알린다.
private struct NotificationsOffRow: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 0) {
                Text("알림이 꺼져 있어요")
                    .font(.caption.weight(.semibold))
                Text("iPhone › Watch › 알림")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .listRowBackground(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.orange.opacity(0.15)))
    }
}

/// 손이 필요한 타이머: 단계가 끝나 다음 단계를 기다리거나, 완성돼 확인을 기다린다. 지난 시간을 센다.
private struct AttentionRow: View {
    let timer: ActiveTimer
    let now: Date
    let compact: Bool

    private var waiting: Bool { timer.isWaitingToAdvance(at: now) }

    /// 무엇이 끝났고 탭하면 무엇이 되는지: "앞면 끝 → 뒷면 3:00" 또는 "완성 · 탭하면 확인"
    private var status: String {
        guard waiting else { return "완성 · 탭하면 확인" }
        let next = timer.steps[timer.startedStep + 1]
        return "\(timer.steps[timer.startedStep].name) 끝 → \(next.name) \(formatClock(next.seconds))"
    }

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            Image(systemName: timer.symbol)
                .font(.system(size: compact ? 12 : 16, weight: .bold))
                .foregroundStyle(.red)
                .frame(width: compact ? 26 : 42, height: compact ? 26 : 42)
                .background(Circle().fill(.white))

            if compact {
                RowTitle(timer: timer)
                Spacer(minLength: 4)
                OvertimeText(since: timer.attentionDate)
                    .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    RowTitle(timer: timer)
                    OvertimeText(since: timer.attentionDate)
                        .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                    Text(status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, compact ? 0 : 4)
    }
}

struct TimerRow: View {
    let timer: ActiveTimer
    let now: Date
    var compact = false

    var body: some View {
        let index = timer.currentStepIndex(at: now) ?? timer.steps.count - 1
        // 흘끗 봤을 때 읽히는 건 "무엇"이 아니라 "얼마나 급한가". 숫자 색은 긴급도로만 쓴다.
        let countdownColor: Color = timer.urgency(at: now) == .soon ? .orange : .white
        let ringSize: CGFloat = compact ? 26 : 42

        HStack(spacing: compact ? 8 : 10) {
            ProgressRing(progress: timer.remainingFraction(at: now), tint: timer.tint.color, lineWidth: compact ? 3 : 4) {
                Image(systemName: timer.symbol)
                    .font(.system(size: compact ? 11 : 15, weight: .semibold))
                    .foregroundStyle(timer.tint.color)
            }
            .frame(width: ringSize, height: ringSize)

            if compact {
                RowTitle(timer: timer, suffix: timer.steps.count > 1 ? " · \(timer.steps[index].name)" : "")
                Spacer(minLength: 4)
                CountdownText(until: timer.stepEndDate(index), now: now)
                    .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(countdownColor)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    RowTitle(timer: timer)
                    CountdownText(until: timer.stepEndDate(index), now: now)
                        .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                        .foregroundStyle(countdownColor)
                    if timer.steps.count > 1 {
                        Text("\(index + 1)/\(timer.steps.count) · \(timer.steps[index].name)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, compact ? 0 : 4)
    }
}

/// 남은 시간만큼 줄어드는 링. 가운데에 원하는 내용을 넣는다.
struct ProgressRing<Content: View>: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 6
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            content
        }
    }
}

/// 시스템이 직접 초를 세는 카운트다운 텍스트.
struct CountdownText: View {
    let until: Date
    let now: Date

    var body: some View {
        Text(timerInterval: min(now, until)...until, countsDown: true)
    }
}

/// 끝난 뒤 지난 시간: "+1:23".
struct OvertimeText: View {
    let since: Date

    var body: some View {
        // "+"와 시간을 한 Text로 이어야 10분이 넘어도 줄이 갈리지 않는다.
        (Text("+") + Text(timerInterval: since...since.addingTimeInterval(ActiveTimer.finishedRetention), countsDown: false))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// 줄 제목: 화구 번호 배지 + 메뉴 이름.
private struct RowTitle: View {
    let timer: ActiveTimer
    var suffix = ""

    var body: some View {
        HStack(spacing: 5) {
            if let burner = timer.burner {
                BurnerBadge(number: burner)
            }
            Text(timer.rowName + suffix)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
        }
    }
}

/// 써 본 메뉴를 한 번에 누르는 버튼 묶음. 많이 쓴 순서로 최대 4개.
private struct QuickAddSection: View {
    @Environment(RecipeStore.self) private var store
    @Environment(KitchenPrefs.self) private var prefs
    @Environment(AddFlow.self) private var flow

    var body: some View {
        let favorites = prefs.usage.favorites(store.recipes)
        if !favorites.isEmpty {
            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(favorites) { recipe in
                        Button {
                            flow.choose(recipe)
                        } label: {
                            VStack(spacing: 3) {
                                RecipeIcon(symbol: recipe.symbol, tint: recipe.tint, size: 30)
                                Text(recipe.name)
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                Text("빠른 추가")
            }
        }
    }
}
