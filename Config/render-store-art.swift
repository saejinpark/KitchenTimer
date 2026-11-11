import AppKit

// App Store 헤더(3840×1646)와 검색 결과(3840×2560) 이미지를 만든다.
// 사용: swift Config/render-store-art.swift <프로젝트 폴더>
//   AppStore/screenshots 의 워치 스크린샷과 앱 아이콘을 써서 AppStore/art 에 저장한다.

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let shots = root.appendingPathComponent("AppStore/screenshots")
let outDir = root.appendingPathComponent("AppStore/art")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func image(_ name: String) -> NSImage {
    NSImage(contentsOf: shots.appendingPathComponent(name))!
}

let icon = NSImage(contentsOf: root.appendingPathComponent("KitchenTimer/Assets.xcassets/AppIcon.appiconset/icon.png"))!

/// 불투명 비트맵 캔버스에 그린다(App Store 이미지는 알파 채널이 없어야 한다).
func render(width: Int, height: Int, to file: String, draw: (CGFloat, CGFloat) -> Void) {
    let cg = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
    draw(CGFloat(width), CGFloat(height))
    let rep = NSBitmapImageRep(cgImage: cg.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(file))
}

func background(_ w: CGFloat, _ h: CGFloat) {
    NSGradient(colors: [rgb(255, 176, 64), rgb(255, 122, 41), rgb(238, 72, 38)])!
        .draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -60)
    // 은은한 빛
    NSGradient(starting: rgb(255, 255, 255, 0.22), ending: rgb(255, 255, 255, 0))!
        .draw(fromCenter: NSPoint(x: w * 0.2, y: h * 0.9), radius: 0,
              toCenter: NSPoint(x: w * 0.2, y: h * 0.9), radius: h * 1.1, options: [])
}

/// 워치 모양 틀 안에 화면을 넣는다. `width`는 틀 바깥 너비.
func drawWatch(_ screen: NSImage, x: CGFloat, y: CGFloat, width: CGFloat, tilt: CGFloat = 0) {
    let bezel = width * 0.07
    let screenW = width - bezel * 2
    let screenH = screenW * 496 / 416
    let height = screenH + bezel * 2
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.translateBy(x: x + width / 2, y: y + height / 2)
    ctx.rotate(by: tilt * .pi / 180)
    ctx.translateBy(x: -width / 2, y: -height / 2)

    // 밴드
    let bandW = width * 0.62
    rgb(40, 40, 44).setFill()
    NSBezierPath(roundedRect: NSRect(x: (width - bandW) / 2, y: -height * 0.35, width: bandW, height: height * 1.7),
                 xRadius: bandW * 0.18, yRadius: bandW * 0.18).fill()

    // 그림자 + 몸체
    ctx.setShadow(offset: CGSize(width: 0, height: -width * 0.04), blur: width * 0.12, color: rgb(90, 20, 0, 0.45).cgColor)
    rgb(22, 22, 24).setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: width, height: height),
                 xRadius: width * 0.22, yRadius: width * 0.22).fill()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // 크라운
    rgb(60, 60, 64).setFill()
    NSBezierPath(roundedRect: NSRect(x: width - width * 0.01, y: height * 0.62, width: width * 0.05, height: height * 0.16),
                 xRadius: width * 0.02, yRadius: width * 0.02).fill()

    // 화면
    let screenRect = NSRect(x: bezel, y: bezel, width: screenW, height: screenH)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screenRect, xRadius: width * 0.16, yRadius: width * 0.16).addClip()
    screen.draw(in: screenRect)
    NSGraphicsContext.restoreGraphicsState()
    ctx.restoreGState()
}

func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, at p: NSPoint) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
    ]
    NSAttributedString(string: s, attributes: attrs).draw(at: p)
}

func drawIcon(x: CGFloat, y: CGFloat, size: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.04), blur: size * 0.15, color: rgb(90, 20, 0, 0.4).cgColor)
    let rect = NSRect(x: x, y: y, width: size, height: size)
    let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.225, yRadius: size * 0.225)
    rgb(255, 255, 255).setFill(); path.fill()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    path.addClip()
    icon.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

let queue = image("watch-1-queue.png")
let running = image("watch-2-running.png")
let detail = image("watch-3-detail.png")
let burner = image("watch-4-burner.png")

// 헤더: 가로로 긴 배너. 가장자리는 기기마다 잘릴 수 있어 글자는 가운데 쪽에 둔다.
render(width: 3840, height: 1646, to: "header-3840x1646.png") { w, h in
    background(w, h)
    drawIcon(x: 560, y: h / 2 + 40, size: 300)
    text("주방 타이머", size: 230, weight: .heavy, color: .white, at: NSPoint(x: 540, y: h / 2 - 280))
    text("워치 하나로 여러 요리를 동시에", size: 104, weight: .semibold, color: rgb(255, 255, 255, 0.92),
         at: NSPoint(x: 548, y: h / 2 - 440))
    drawWatch(detail, x: 2050, y: 360, width: 720, tilt: 6)
    drawWatch(queue, x: 2720, y: 300, width: 800, tilt: -4)
}

// 검색 결과: 3:2. 위에 이름과 한 줄 소개, 아래에 워치 화면 세 개.
render(width: 3840, height: 2560, to: "search-3840x2560.png") { w, h in
    background(w, h)
    drawIcon(x: 300, y: h - 640, size: 360)
    text("주방 타이머", size: 220, weight: .heavy, color: .white, at: NSPoint(x: 720, y: h - 530))
    text("뒤집을 때도, 다 됐을 때도 손목이 알려줘요", size: 100, weight: .semibold, color: rgb(255, 255, 255, 0.92),
         at: NSPoint(x: 728, y: h - 680))
    let ww: CGFloat = 900
    drawWatch(queue, x: 340, y: 300, width: ww, tilt: 4)
    drawWatch(detail, x: (w - ww) / 2, y: 380, width: ww)
    drawWatch(burner, x: w - ww - 340, y: 300, width: ww, tilt: -4)
}

print("saved to \(outDir.path)")
