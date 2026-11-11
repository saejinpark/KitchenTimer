import SwiftUI

/// 메뉴 아이콘: 색 그라디언트 위에 흰 SF 심볼.
struct RecipeIcon: View {
    let symbol: String
    let tint: RecipeTint
    var size: CGFloat = 32
    var cornerRadius: CGFloat? = nil  // nil이면 원형

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(shape.fill(tint.color.gradient))
    }

    private var shape: AnyShape {
        if let cornerRadius {
            AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            AnyShape(Circle())
        }
    }
}
