import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Renders the app icon (1024×1024) in three variants: light, dark, tinted.
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

let orange = color(0xFF7A2F)
let red = color(0xE8234F)

/// Dumbbell centred at the origin, horizontal.
func dumbbellPath() -> CGPath {
    let path = CGMutablePath()
    func rect(_ cx: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
        path.addRoundedRect(in: CGRect(x: cx - w / 2, y: -h / 2, width: w, height: h), cornerWidth: r, cornerHeight: r)
    }
    rect(0, 400, 54, 27)                 // bar between the plates
    for side: CGFloat in [-1, 1] {
        rect(side * 175, 78, 380, 30)    // big plate
        rect(side * 262, 64, 272, 26)    // small plate
        rect(side * 312, 56, 92, 20)     // end cap (joined to the small plate)
    }
    return path
}

func render(_ name: String, draw: (CGContext) -> Void) {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(ctx)
    let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(url.path)")
}

func withDumbbell(_ ctx: CGContext, _ body: (CGPath) -> Void) {
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
    ctx.rotate(by: .pi / 4)             // diagonal, rising to the right
    ctx.scaleBy(x: 1.08, y: 1.08)
    body(dumbbellPath())
    ctx.restoreGState()
}

func linearGradient(_ ctx: CGContext, _ colors: [CGColor]) {
    let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: CGFloat(size), y: 0), options: [])
}

// Light: warm gradient background, white dumbbell.
render("AppIcon.png") { ctx in
    linearGradient(ctx, [orange, red])
    // soft highlight in the upper left
    let glow = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 260, y: 820), startRadius: 0,
                           endCenter: CGPoint(x: 260, y: 820), endRadius: 700, options: [])
    withDumbbell(ctx) { path in
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x7A0E24, 0.35))
        ctx.addPath(path)
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillPath()
    }
}

// Dark: transparent background, dumbbell in the brand gradient.
render("AppIcon-Dark.png") { ctx in
    withDumbbell(ctx) { path in
        ctx.addPath(path)
        ctx.clip()
        ctx.rotate(by: -.pi / 4)
        let gradient = CGGradient(colorsSpace: space, colors: [orange, red] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: -380, y: 380), end: CGPoint(x: 380, y: -380), options: [])
    }
}

// Tinted: grayscale dumbbell on transparent background (system applies the tint).
render("AppIcon-Tinted.png") { ctx in
    withDumbbell(ctx) { path in
        ctx.addPath(path)
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillPath()
    }
}
