import SwiftUI

@main
struct KitchenTimerApp: App {
    var body: some Scene {
        WindowGroup {
            RecipeListView()
                .environment(RecipeStore.shared)
                .task {
                    RecipeSync.shared.activate()
                    RecipeSync.shared.send(RecipeStore.shared.recipes)
                }
        }
    }
}
