import SwiftUI

/// 메뉴 목록. 편집 내용은 바로 워치로 동기화된다.
struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store
    @State private var path: [UUID] = []

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $path) {
            Group {
                if store.recipes.isEmpty {
                    ContentUnavailableView {
                        Label("메뉴 없음", systemImage: "fork.knife")
                    } description: {
                        Text("자주 만드는 메뉴와 조리 시간을 등록하면\nApple Watch에서 바로 시작할 수 있어요.")
                    } actions: {
                        Button("메뉴 추가", systemImage: "plus", action: addRecipe)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(store.recipes) { recipe in
                                NavigationLink(value: recipe.id) {
                                    RecipeRow(recipe: recipe)
                                }
                            }
                            .onDelete { store.recipes.remove(atOffsets: $0) }
                            .onMove { store.recipes.move(fromOffsets: $0, toOffset: $1) }
                        } footer: {
                            Label("Apple Watch에 자동으로 동기화돼요", systemImage: "applewatch")
                        }
                    }
                }
            }
            .navigationTitle("메뉴")
            .toolbar {
                if !store.recipes.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("메뉴 추가", systemImage: "plus", action: addRecipe)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let index = store.recipes.firstIndex(where: { $0.id == id }) {
                    RecipeEditView(recipe: $store.recipes[index])
                }
            }
        }
    }

    private func addRecipe() {
        let recipe = Recipe(name: "새 메뉴", symbol: "fork.knife", tint: .orange,
                            steps: [CookStep(name: "조리", seconds: 5 * 60)])
        store.recipes.append(recipe)
        path.append(recipe.id)
    }
}

private struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 14) {
            RecipeIcon(symbol: recipe.symbol, tint: recipe.tint, size: 44, cornerRadius: 11)
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name)
                    .font(.body.weight(.semibold))
                HStack(spacing: 10) {
                    Label(formatDuration(recipe.totalSeconds), systemImage: "timer")
                    if recipe.steps.count > 1 {
                        Label("\(recipe.steps.count)단계", systemImage: "list.number")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .labelStyle(CompactLabelStyle())
            }
        }
        .padding(.vertical, 4)
    }
}

/// 아이콘과 글자 간격을 좁힌 라벨.
struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}
