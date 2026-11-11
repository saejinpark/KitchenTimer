import SwiftUI

struct RecipeEditView: View {
    @Binding var recipe: Recipe
    @State private var editingStep: StepRef?

    var body: some View {
        Form {
            Section {
                VStack(spacing: 14) {
                    RecipeIcon(symbol: recipe.symbol, tint: recipe.tint, size: 84, cornerRadius: 20)
                        .shadow(color: recipe.tint.color.opacity(0.35), radius: 10, y: 4)
                    TextField("메뉴 이름", text: $recipe.name)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("색상") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(RecipeTint.allCases) { tint in
                        Button {
                            recipe.tint = tint
                        } label: {
                            Circle()
                                .fill(tint.color.gradient)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if recipe.tint == tint {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("아이콘") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(Recipe.symbolChoices, id: \.self) { symbol in
                        let selected = recipe.symbol == symbol
                        Button {
                            recipe.symbol = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(selected ? .white : .secondary)
                                .frame(width: 42, height: 42)
                                .background(
                                    Circle().fill(selected ? AnyShapeStyle(recipe.tint.color.gradient)
                                                           : AnyShapeStyle(Color(.tertiarySystemFill)))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                    Button {
                        editingStep = StepRef(id: step.id)
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.footnote.weight(.bold).monospacedDigit())
                                .foregroundStyle(recipe.tint.color)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(recipe.tint.color.opacity(0.15)))
                            Text(step.name)
                                .foregroundStyle(Color(.label))
                            Spacer()
                            Text(formatClock(step.seconds))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(Color(.secondaryLabel))
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                    }
                }
                .onDelete { offsets in
                    // 단계가 하나도 없으면 워치에서 시작할 수 없으므로 하나는 남긴다.
                    guard recipe.steps.count > offsets.count else { return }
                    recipe.steps.remove(atOffsets: offsets)
                }
                .onMove { recipe.steps.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    let step = CookStep(name: "단계 \(recipe.steps.count + 1)", seconds: 60)
                    recipe.steps.append(step)
                    editingStep = StepRef(id: step.id)
                } label: {
                    Label("단계 추가", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("조리 단계")
            } footer: {
                Label("총 \(formatDuration(recipe.totalSeconds)) · 단계가 끝날 때마다 워치가 알려줘요",
                      systemImage: "bell.badge")
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingStep) { ref in
            if let index = recipe.steps.firstIndex(where: { $0.id == ref.id }) {
                StepEditorSheet(step: $recipe.steps[index], tint: recipe.tint)
            }
        }
    }
}

/// 단계 이름과 시간을 시계 앱 타이머처럼 휠로 고른다.
private struct StepEditorSheet: View {
    @Binding var step: CookStep
    let tint: RecipeTint
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                TextField("단계 이름", text: $step.name)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal)

                HStack(spacing: 0) {
                    Picker("분", selection: minutes) {
                        ForEach(0..<181) { Text("\($0)분").tag($0) }
                    }
                    Picker("초", selection: seconds) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0)초").tag($0) }
                    }
                }
                .pickerStyle(.wheel)
            }
            .padding(.top, 8)
            .navigationTitle("단계 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료", systemImage: "checkmark") { dismiss() }
                        .tint(tint.color)
                }
            }
        }
        .presentationDetents([.height(420)])
    }

    private var minutes: Binding<Int> {
        Binding { step.seconds / 60 } set: { step.seconds = max(5, $0 * 60 + step.seconds % 60) }
    }

    private var seconds: Binding<Int> {
        Binding { step.seconds % 60 / 5 * 5 } set: { step.seconds = max(5, step.seconds / 60 * 60 + $0) }
    }
}

/// 편집 중인 단계를 sheet(item:)으로 띄우기 위한 식별자.
private struct StepRef: Identifiable {
    let id: CookStep.ID
}
