import Cocoa
import CoreGraphics

let width: CGFloat = 660
let height: CGFloat = 420
let scale: CGFloat = 2.0 // Retina

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: Int(width * scale),
    height: Int(height * scale),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create CGContext")
}

context.scaleBy(x: scale, y: scale)

// 1. Pure deep matte black background
context.setFillColor(CGColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1.0))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

// Subtle top cinema glow
let gradientColors = [
    CGColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.35),
    CGColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 0.0)
] as CFArray
if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0]) {
    context.drawLinearGradient(glowGradient, start: CGPoint(x: width/2, y: height), end: CGPoint(x: width/2, y: 0), options: [])
}

// Coordinate note: In CGContext default (0,0) is bottom-left!
// Finder icon for Somnius is placed around x: 170, y_finder: 170 (which is y_cg = height - 170 = 250)
// Icon size is 120x120.
// Under App is around y_cg = 100.
// Middle arrow is at y_cg = 250 (middle height between icons).
// Under Applications is at y_cg = 100.

let leftX: CGFloat = 175
let rightX: CGFloat = 485
let iconY_CG: CGFloat = 240
let underY_CG: CGFloat = 95

// 2. In the Middle: Stylish arrow "— — — ▶"
let arrowY = iconY_CG
let startX = leftX + 85
let endX = rightX - 85

context.saveGState()
context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.45))
context.setLineWidth(2.5)
context.setLineDash(phase: 0, lengths: [9.0, 6.0])

let arrowPath = CGMutablePath()
arrowPath.move(to: CGPoint(x: startX, y: arrowY))
arrowPath.addLine(to: CGPoint(x: endX - 12, y: arrowY))
context.addPath(arrowPath)
context.strokePath()

// Arrowhead pointing right
context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8))
let headPath = CGMutablePath()
headPath.move(to: CGPoint(x: endX, y: arrowY))
headPath.addLine(to: CGPoint(x: endX - 14, y: arrowY + 7))
headPath.addLine(to: CGPoint(x: endX - 14, y: arrowY - 7))
headPath.closeSubpath()
context.addPath(headPath)
context.fillPath()
context.restoreGState()

// 3. Under the App: Glowing Play Button
context.saveGState()
let playCenter = CGPoint(x: leftX, y: underY_CG)
let playRadius: CGFloat = 24

// Play button circular background & subtle border
context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08))
context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.25))
context.setLineWidth(1.5)
context.addArc(center: playCenter, radius: playRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
context.drawPath(using: .fillStroke)

// Play triangle icon (pointing right)
context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
context.setShadow(offset: .zero, blur: 8, color: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5))
let triPath = CGMutablePath()
let triSize: CGFloat = 11
triPath.move(to: CGPoint(x: playCenter.x + triSize * 0.9, y: playCenter.y))
triPath.addLine(to: CGPoint(x: playCenter.x - triSize * 0.6, y: playCenter.y + triSize * 0.8))
triPath.addLine(to: CGPoint(x: playCenter.x - triSize * 0.6, y: playCenter.y - triSize * 0.8))
triPath.closeSubpath()
context.addPath(triPath)
context.fillPath()
context.restoreGState()

// Label under Play button
let playAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.65)
]
let playStr = NSAttributedString(string: "Drag to Applications", attributes: playAttrs)
let playStrSize = playStr.size()
let playStrRect = CGRect(x: leftX - playStrSize.width/2, y: underY_CG - 40, width: playStrSize.width, height: playStrSize.height)
// Convert to AppKit drawing
let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
playStr.draw(in: playStrRect)
NSGraphicsContext.restoreGraphicsState()

// 4. Under Applications: Glowing Somnius Moon
context.saveGState()
let moonCenter = CGPoint(x: rightX, y: underY_CG)
let moonRadius: CGFloat = 24

// Ambient moon glow
context.setShadow(offset: .zero, blur: 20, color: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.6))

// Moon radial fill
let moonColors = [
    CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
    CGColor(red: 0.86, green: 0.88, blue: 0.92, alpha: 1.0)
] as CFArray
if let moonGradient = CGGradient(colorsSpace: colorSpace, colors: moonColors, locations: [0.0, 1.0]) {
    context.saveGState()
    context.addArc(center: moonCenter, radius: moonRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
    context.clip()
    context.drawRadialGradient(moonGradient, startCenter: moonCenter, startRadius: 2, endCenter: moonCenter, endRadius: moonRadius, options: [])
    context.restoreGState()
}
context.restoreGState()

// Moon subtle crater texture / crescent shading
context.saveGState()
context.setFillColor(CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.06))
context.addArc(center: CGPoint(x: moonCenter.x + 8, y: moonCenter.y + 6), radius: 6, startAngle: 0, endAngle: .pi * 2, clockwise: true)
context.fillPath()
context.addArc(center: CGPoint(x: moonCenter.x - 7, y: moonCenter.y - 8), radius: 8, startAngle: 0, endAngle: .pi * 2, clockwise: true)
context.fillPath()
context.restoreGState()

// Label under Moon
let moonAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.65)
]
let moonStr = NSAttributedString(string: "Ready to Stream", attributes: moonAttrs)
let moonStrSize = moonStr.size()
let moonStrRect = CGRect(x: rightX - moonStrSize.width/2, y: underY_CG - 40, width: moonStrSize.width, height: moonStrSize.height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
moonStr.draw(in: moonStrRect)
NSGraphicsContext.restoreGraphicsState()

// Export PNG image
guard let cgImage = context.makeImage() else {
    fatalError("Failed to make CGImage")
}

let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
bitmapRep.size = NSSize(width: width, height: height)
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to convert to PNG")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build_output/dmg_background.png"
try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Successfully generated DMG background at \(outputPath)")
