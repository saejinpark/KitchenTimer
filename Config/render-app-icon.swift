import AppKit

// 주방 타이머 아이콘: 따뜻한 주황 배경 + 흰 다이얼(위에 손잡이) + 줄어드는 링 + 가운데 불꽃
let size: CGFloat = 1024
let cg = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a) }

// 배경
NSGradient(colors: [rgb(255, 176, 64), rgb(255, 122, 41), rgb(238, 72, 38)])!
    .draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)
// 위쪽 은은한 하이라이트
NSGradient(starting: rgb(255, 255, 255, 0.22), ending: rgb(255, 255, 255, 0))!
    .draw(fromCenter: NSPoint(x: 330, y: 900), radius: 0, toCenter: NSPoint(x: 330, y: 900), radius: 620, options: [])

let center = NSPoint(x: 512, y: 486)
let bodyR: CGFloat = 318

// 그림자 + 손잡이 + 몸체
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -22), blur: 48, color: rgb(120, 30, 0, 0.35).cgColor)
rgb(255, 250, 244).setFill()
NSBezierPath(roundedRect: NSRect(x: center.x - 26, y: center.y + bodyR - 30, width: 52, height: 78), xRadius: 18, yRadius: 18).fill()
NSBezierPath(roundedRect: NSRect(x: center.x - 92, y: center.y + bodyR + 30, width: 184, height: 62), xRadius: 31, yRadius: 31).fill()
NSBezierPath(ovalIn: NSRect(x: center.x - bodyR, y: center.y - bodyR, width: bodyR * 2, height: bodyR * 2)).fill()
cg.restoreGState()
// 손잡이 기둥은 그림자 위에 다시 그려 몸체와 같은 색으로
rgb(255, 250, 244).setFill()
NSBezierPath(roundedRect: NSRect(x: center.x - 26, y: center.y + bodyR - 30, width: 52, height: 64), xRadius: 10, yRadius: 10).fill()

// 눈금 12개
rgb(255, 122, 41, 0.35).setFill()
for i in 0..<12 {
    let a = CGFloat(i) / 12 * 2 * .pi
    let r1: CGFloat = 272, w: CGFloat = 14, h: CGFloat = i % 3 == 0 ? 34 : 20
    cg.saveGState()
    cg.translateBy(x: center.x, y: center.y)
    cg.rotate(by: -a)
    NSBezierPath(roundedRect: NSRect(x: -w/2, y: r1 - h, width: w, height: h), xRadius: w/2, yRadius: w/2).fill()
    cg.restoreGState()
}

// 링: 트랙 + 남은 시간(12시부터 시계방향 3/4)
let ringR: CGFloat = 200, lw: CGFloat = 58
let track = NSBezierPath(); track.appendArc(withCenter: center, radius: ringR, startAngle: 0, endAngle: 360)
track.lineWidth = lw; rgb(255, 122, 41, 0.16).setStroke(); track.stroke()

let arc = NSBezierPath(); arc.appendArc(withCenter: center, radius: ringR, startAngle: 90, endAngle: 90 - 270, clockwise: true)
arc.lineWidth = lw; arc.lineCapStyle = .round
cg.saveGState()
arc.setClip()  // 그라디언트를 링 모양으로
cg.restoreGState()
let stroked = arc.cgPathStroked(lineWidth: lw)
cg.saveGState()
cg.addPath(stroked); cg.clip()
NSGradient(starting: rgb(255, 156, 52), ending: rgb(240, 70, 36))!.draw(in: NSRect(x: center.x - ringR - lw, y: center.y - ringR - lw, width: (ringR + lw) * 2, height: (ringR + lw) * 2), angle: -45)
cg.restoreGState()

// 가운데 불꽃
let config = NSImage.SymbolConfiguration(pointSize: 190, weight: .bold)
    .applying(.init(paletteColors: [rgb(240, 80, 36)]))
let flame = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
let s = flame.size
flame.draw(in: NSRect(x: center.x - s.width/2, y: center.y - s.height/2 + 4, width: s.width, height: s.height))

let out = NSBitmapImageRep(cgImage: cg.makeImage()!)
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

extension NSBezierPath {
    func cgPathStroked(lineWidth: CGFloat) -> CGPath {
        let p = CGMutablePath()
        var pts = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            switch element(at: i, associatedPoints: &pts) {
            case .moveTo: p.move(to: pts[0])
            case .lineTo: p.addLine(to: pts[0])
            case .curveTo, .cubicCurveTo: p.addCurve(to: pts[2], control1: pts[0], control2: pts[1])
            case .closePath: p.closeSubpath()
            default: break
            }
        }
        return p.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)
    }
}
