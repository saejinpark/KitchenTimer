import SwiftUI

/// 폰에서 등록한 메뉴 중 하나를 골라 큐 뒤에 추가한다. 많이 쓴 메뉴가 위로 온다.
struct AddRecipeView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(KitchenPrefs.self) private var prefs
    @Environment(AddFlow.self) private var flow
    @State private var showingGuide = false

    var body: some View {
        @Bindable var prefs = prefs
        if store.recipes.isEmpty {
            ContentUnavailableView("메뉴 없음", systemImage: "fork.knife",
                                   description: Text("iPhone에서 메뉴를 등록하세요"))
        } else {
            List {
                Section {
                    ForEach(prefs.usage.ranked(store.recipes)) { recipe in
                        Button {
                            flow.choose(recipe)
                        } label: {
                            HStack(spacing: 10) {
                                RecipeIcon(symbol: recipe.symbol, tint: recipe.tint, size: 34)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(recipe.name)
                                        .font(.body.weight(.medium))
                                        .lineLimit(1)
                                    HStack(spacing: 3) {
                                        Image(systemName: "timer").imageScale(.small)
                                        Text(summary(recipe))
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("메뉴 추가")
                }

                Section {
                    Toggle(isOn: $prefs.askBurner) {
                        Label("화구 번호 묻기", systemImage: "flame")
                    }
                    if prefs.askBurner {
                        // 워치 기본 Stepper는 글자를 화면 가득 키워서 한 줄짜리로 직접 만든다.
                        HStack {
                            Button("화구 줄이기", systemImage: "minus") {
                                prefs.burnerCount = max(KitchenPrefs.burnerRange.lowerBound, prefs.burnerCount - 1)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .disabled(prefs.burnerCount <= KitchenPrefs.burnerRange.lowerBound)
                            Spacer()
                            Text("화구 \(prefs.burnerCount)개")
                                .font(.body.monospacedDigit())
                            Spacer()
                            Button("화구 늘리기", systemImage: "plus") {
                                prefs.burnerCount = min(KitchenPrefs.burnerRange.upperBound, prefs.burnerCount + 1)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .disabled(prefs.burnerCount >= KitchenPrefs.burnerRange.upperBound)
                        }
                    }
                    Button {
                        showingGuide = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("손목 내려도 계속 울리게")
                                if !prefs.stayOnGuideSeen {
                                    Text("설정 한 번 필요")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        } icon: {
                            Image(systemName: "applewatch.watchface")
                        }
                    }
                } header: {
                    Text("식당 모드")
                } footer: {
                    Text("켜면 추가할 때 어느 화구인지 고르고, 목록에 번호가 붙어요.")
                }
            }
            .sheet(isPresented: $showingGuide) {
                StayOnScreenGuide()
            }
            // 식당 모드를 처음 켤 때 한 번 안내한다.
            .onChange(of: prefs.askBurner) { _, isOn in
                if isOn && !prefs.stayOnGuideSeen { showingGuide = true }
            }
        }
    }

    private func summary(_ recipe: Recipe) -> String {
        let total = formatDuration(recipe.totalSeconds)
        return recipe.steps.count > 1 ? "\(total) · \(recipe.steps.count)단계" : total
    }
}
