import AppKit
import CoreGraphics

func drawIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }
    ctx.saveGState()

    // Flip so y=0 is bottom-left
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    let r = s * 0.18  // corner radius for app icon shape

    // --- Background: deep charcoal ---
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                        cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.addPath(bgPath)
    ctx.setFillColor(CGColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1))
    ctx.fillPath()

    // --- Dock bar: bottom 28% of icon ---
    let dockH = s * 0.28
    let dockY = s - dockH
    let dockRect = CGRect(x: 0, y: dockY, width: s, height: dockH)
    let dockPath = CGMutablePath()
    dockPath.addRect(CGRect(x: 0, y: dockY, width: s, height: dockH))
    ctx.addPath(dockPath)
    ctx.setFillColor(CGColor(red: 0.22, green: 0.24, blue: 0.28, alpha: 1))
    ctx.fillPath()

    // Dock separator line
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
    ctx.setLineWidth(s * 0.012)
    ctx.move(to: CGPoint(x: 0, y: dockY))
    ctx.addLine(to: CGPoint(x: s, y: dockY))
    ctx.strokePath()

    // Small app circles in the dock
    let nDots = 5
    let dotR = s * 0.055
    let totalW = CGFloat(nDots) * dotR * 2 + CGFloat(nDots - 1) * dotR * 0.8
    let startX = (s - totalW) / 2 + dotR
    let dotY = dockY + dockH / 2
    let dotColors: [CGColor] = [
        CGColor(red: 0.98, green: 0.36, blue: 0.35, alpha: 1),
        CGColor(red: 0.40, green: 0.78, blue: 0.96, alpha: 1),
        CGColor(red: 0.35, green: 0.82, blue: 0.58, alpha: 1),
        CGColor(red: 0.98, green: 0.73, blue: 0.27, alpha: 1),
        CGColor(red: 0.72, green: 0.55, blue: 0.98, alpha: 1),
    ]
    for i in 0..<nDots {
        let cx = startX + CGFloat(i) * (dotR * 2 + dotR * 0.8)
        ctx.setFillColor(dotColors[i])
        ctx.addEllipse(in: CGRect(x: cx - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2))
        ctx.fillPath()
    }

    // --- Lock body (shackle arc + body rect) ---
    // Lock is centred in the upper area (above dock), shifted slightly up
    let lockCX = s * 0.5
    let lockCY = dockY * 0.46

    let bodyW = s * 0.38
    let bodyH = s * 0.28
    let bodyX = lockCX - bodyW / 2
    let bodyY = lockCY - bodyH * 0.1
    let bodyCorner = bodyW * 0.14

    // Body shadow/glow layer
    ctx.setShadow(offset: .zero, blur: s * 0.06, color: CGColor(red: 1, green: 0.80, blue: 0.2, alpha: 0.45))
    let bodyPath = CGPath(roundedRect: CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH),
                          cornerWidth: bodyCorner, cornerHeight: bodyCorner, transform: nil)
    ctx.addPath(bodyPath)
    ctx.setFillColor(CGColor(red: 0.98, green: 0.78, blue: 0.18, alpha: 1))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Keyhole
    let khR = bodyW * 0.13
    let khCX = lockCX
    let khCY = bodyY + bodyH * 0.42
    ctx.setFillColor(CGColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1))
    ctx.addEllipse(in: CGRect(x: khCX - khR, y: khCY - khR, width: khR * 2, height: khR * 2))
    ctx.fillPath()
    // keyhole stem
    let stemW = khR * 0.85
    let stemH = khR * 1.2
    ctx.addRect(CGRect(x: khCX - stemW / 2, y: khCY, width: stemW, height: stemH))
    ctx.fillPath()

    // Shackle (arc above body)
    let shW = bodyW * 0.52
    let shLineW = s * 0.072
    let shCX = lockCX
    let shBottomY = bodyY + shLineW * 0.5
    let shTopY = shBottomY - bodyH * 0.56
    let shR = shW / 2

    let shackle = CGMutablePath()
    shackle.addArc(center: CGPoint(x: shCX, y: shBottomY - shR),
                   radius: shR,
                   startAngle: .pi,
                   endAngle: 0,
                   clockwise: false)
    ctx.addPath(shackle)
    ctx.setStrokeColor(CGColor(red: 0.98, green: 0.78, blue: 0.18, alpha: 1))
    ctx.setLineWidth(shLineW)
    ctx.setLineCap(.round)
    ctx.strokePath()

    ctx.restoreGState()
    return image
}

let sizes = [1024, 512, 256, 128, 64, 32, 16]
let iconsetDir = "/Users/vdejesus/Azure Git Repos/LockBar/LockBar.iconset"

let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

for size in sizes {
    for scale in [1, 2] {
        let px = size * scale
        let img = drawIcon(size: px)
        let filename = scale == 2 ? "icon_\(size)x\(size)@2x.png" : "icon_\(size)x\(size).png"
        let path = "\(iconsetDir)/\(filename)"
        guard let tiff = img.tiffRepresentation,
              let bmp = NSBitmapImageRep(data: tiff),
              let png = bmp.representation(using: .png, properties: [:]) else {
            print("Failed at \(px)px"); continue
        }
        try! png.write(to: URL(fileURLWithPath: path))
        print("Wrote \(filename)")
    }
}
print("Done")
