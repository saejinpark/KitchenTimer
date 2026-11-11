import SwiftUI

/// "시계로 돌아가기"를 1시간으로 바꾸도록 안내한다.
///
/// 워치는 손목을 내리고 2분 뒤 시계 화면으로 돌아간다. 앱이 뒤로 가면 스마트 알람을 다시 걸 수 없어서,
/// 연달아 끝나는 타이머 중 두 번째부터는 진동이 한 번만 온다. 앱이 계속 앞에 있으면 매번 앱 안에서 울린다.
/// 워치에는 설정 앱을 바로 여는 방법이 없어서 경로를 보여 준다.
struct StayOnScreenGuide: View {
    @Environment(KitchenPrefs.self) private var prefs
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "applewatch.watchface")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)

                Text("손목을 내려도\n계속 울리게")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text("워치는 손목을 내리고 2분이 지나면 시계로 돌아가요. 그러면 연달아 끝나는 타이머는 두 번째부터 진동이 한 번만 와요.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                GuideStep(number: 1, symbol: "gearshape.fill", title: "설정 앱", detail: "일반")
                GuideStep(number: 2, symbol: "clock.arrow.circlepath", title: "시계로 돌아가기", detail: "주방 타이머 선택")
                GuideStep(number: 3, symbol: "timer", title: "사용자 설정 켜기", detail: "1시간 후 선택")

                Label("iPhone Watch 앱 › 일반에서도 바꿀 수 있어요", systemImage: "iphone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button {
                    prefs.stayOnGuideSeen = true
                    dismiss()
                } label: {
                    Text("알겠어요")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct GuideStep: View {
    let number: Int
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.orange))
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.1)))
    }
}
