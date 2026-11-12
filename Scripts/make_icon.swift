// Draws the app icon: Claude orange rounded square with a cream clock outline.
// Usage: swift Scripts/make_icon.swift Resources/AppIcon.iconset
//        iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}

let orange = color(217, 119, 87)      // #D97757
let orangeTop = color(226, 137, 108)
let orangeBottom = color(201, 104, 74)
let cream = color(250, 249, 245)

/// Renders the icon at `px` pixels square, drawn on a 1024-point grid.
func render(_ px: Int) -> Data {
    let ctx = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let scale = CGFloat(px) / 1024
    ctx.scaleBy(x: scale, y: scale)

    // macOS icon grid: 824-point body centered in 1024, with room for the shadow.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.28))
    ctx.addPath(shape)
    ctx.setFillColor(orange)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: sRGB, colors: [orangeTop, orangeBottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Clock: outline, 10:10 hands, center dot.
    let center = CGPoint(x: 512, y: 512)
    ctx.setStrokeColor(cream)
    ctx.setFillColor(cream)
    ctx.setLineCap(.round)

    ctx.setLineWidth(50)
    ctx.strokeEllipse(in: CGRect(x: center.x - 255, y: center.y - 255, width: 510, height: 510))

    func hand(degreesFromTwelve: CGFloat, length: CGFloat, width: CGFloat) {
        let radians = degreesFromTwelve * .pi / 180
        ctx.setLineWidth(width)
        ctx.move(to: center)
        ctx.addLine(to: CGPoint(x: center.x + sin(radians) * length, y: center.y + cos(radians) * length))
        ctx.strokePath()
    }
    hand(degreesFromTwelve: -55, length: 125, width: 44)   // hour, just past 10
    hand(degreesFromTwelve: 60, length: 180, width: 40)    // minute, at 2

    ctx.fillEllipse(in: CGRect(x: center.x - 32, y: center.y - 32, width: 64, height: 64))

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(base)x\(base).png"))
    try render(base * 2).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(base)x\(base)@2x.png"))
}
print("Wrote \(outDir)")
