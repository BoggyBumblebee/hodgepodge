import AppKit
import Foundation

struct IconRenderer {
    let size: CGFloat

    var rect: CGRect { CGRect(x: 0, y: 0, width: size, height: size) }

    func render() -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        defer { image.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else {
            return image
        }

        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        drawBackground(in: context)
        drawGlow(in: context)
        drawGlassShadow(in: context)
        drawGlass(in: context)
        drawBeer(in: context)
        drawFoam(in: context)
        drawHighlights(in: context)

        return image
    }

    private func drawBackground(in context: CGContext) {
        let rounded = roundedRect(
            insetBy: size * 0.035,
            radius: size * 0.23
        )

        context.saveGState()
        context.addPath(rounded.cgPath)
        context.clip()

        let colors = [
            NSColor(calibratedRed: 0.19, green: 0.16, blue: 0.10, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.36, green: 0.23, blue: 0.08, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.56, green: 0.34, blue: 0.09, alpha: 1).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0, 0.48, 1]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations)!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.minY),
            options: []
        )

        let topGlowColors = [
            NSColor(calibratedRed: 1.0, green: 0.93, blue: 0.78, alpha: 0.28).cgColor,
            NSColor.clear.cgColor
        ] as CFArray
        let topGlow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: topGlowColors, locations: [0, 1])!
        context.drawRadialGradient(
            topGlow,
            startCenter: CGPoint(x: rect.midX, y: rect.maxY - size * 0.18),
            startRadius: 0,
            endCenter: CGPoint(x: rect.midX, y: rect.maxY - size * 0.18),
            endRadius: size * 0.7,
            options: []
        )

        context.restoreGState()
    }

    private func drawGlow(in context: CGContext) {
        let glowRect = CGRect(
            x: size * 0.22,
            y: size * 0.12,
            width: size * 0.56,
            height: size * 0.66
        )

        context.saveGState()
        let glowColors = [
            NSColor(calibratedRed: 1.0, green: 0.83, blue: 0.42, alpha: 0.32).cgColor,
            NSColor.clear.cgColor
        ] as CFArray
        let glowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 1])!
        context.drawRadialGradient(
            glowGradient,
            startCenter: CGPoint(x: glowRect.midX, y: glowRect.midY),
            startRadius: 0,
            endCenter: CGPoint(x: glowRect.midX, y: glowRect.midY),
            endRadius: glowRect.width * 0.7,
            options: []
        )
        context.restoreGState()
    }

    private func drawGlassShadow(in context: CGContext) {
        let shadowPath = NSBezierPath(roundedRect: glassRect.offsetBy(dx: 0, dy: -size * 0.016), xRadius: size * 0.05, yRadius: size * 0.05)
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -size * 0.01),
            blur: size * 0.05,
            color: NSColor(calibratedWhite: 0, alpha: 0.24).cgColor
        )
        context.setFillColor(NSColor(calibratedWhite: 0, alpha: 0.20).cgColor)
        context.addPath(shadowPath.cgPath)
        context.fillPath()
        context.restoreGState()
    }

    private var glassRect: CGRect {
        CGRect(
            x: size * 0.31,
            y: size * 0.19,
            width: size * 0.38,
            height: size * 0.58
        )
    }

    private func drawGlass(in context: CGContext) {
        let path = glassPath
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()

        let glassColors = [
            NSColor(calibratedWhite: 1, alpha: 0.26).cgColor,
            NSColor(calibratedWhite: 1, alpha: 0.16).cgColor,
            NSColor(calibratedWhite: 0.92, alpha: 0.10).cgColor
        ] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glassColors, locations: [0, 0.5, 1])!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: glassRect.minX, y: glassRect.maxY),
            end: CGPoint(x: glassRect.maxX, y: glassRect.minY),
            options: []
        )

        context.restoreGState()

        context.saveGState()
        context.setLineWidth(size * 0.016)
        context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.48).cgColor)
        context.addPath(path.cgPath)
        context.strokePath()
        context.restoreGState()
    }

    private var glassPath: NSBezierPath {
        let path = NSBezierPath()
        let topInset = size * 0.028
        let baseInset = size * 0.06
        let topY = glassRect.maxY
        let bottomY = glassRect.minY + size * 0.01
        path.move(to: CGPoint(x: glassRect.minX + topInset, y: topY))
        path.line(to: CGPoint(x: glassRect.maxX - topInset, y: topY))
        path.line(to: CGPoint(x: glassRect.maxX - baseInset, y: bottomY))
        path.curve(
            to: CGPoint(x: glassRect.minX + baseInset, y: bottomY),
            controlPoint1: CGPoint(x: glassRect.maxX - size * 0.03, y: glassRect.minY),
            controlPoint2: CGPoint(x: glassRect.minX + size * 0.03, y: glassRect.minY)
        )
        path.close()
        return path
    }

    private func drawBeer(in context: CGContext) {
        let beerRect = glassRect.insetBy(dx: size * 0.028, dy: size * 0.028)
        let beerPath = NSBezierPath(roundedRect: beerRect, xRadius: size * 0.04, yRadius: size * 0.04)

        context.saveGState()
        context.addPath(glassPath.cgPath)
        context.clip()
        context.addPath(beerPath.cgPath)
        context.clip()

        let colors = [
            NSColor(calibratedRed: 0.98, green: 0.75, blue: 0.22, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.91, green: 0.53, blue: 0.08, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.71, green: 0.32, blue: 0.02, alpha: 1).cgColor
        ] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.52, 1])!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: beerRect.midX, y: beerRect.maxY),
            end: CGPoint(x: beerRect.midX, y: beerRect.minY),
            options: []
        )

        context.setFillColor(NSColor(calibratedWhite: 1, alpha: 0.14).cgColor)
        context.fill(CGRect(x: beerRect.minX + size * 0.028, y: beerRect.minY + size * 0.02, width: size * 0.028, height: beerRect.height - size * 0.06))

        context.setFillColor(NSColor(calibratedRed: 0.78, green: 0.35, blue: 0.02, alpha: 0.18).cgColor)
        context.fill(CGRect(x: beerRect.maxX - size * 0.05, y: beerRect.minY, width: size * 0.036, height: beerRect.height))

        context.restoreGState()
    }

    private func drawFoam(in context: CGContext) {
        let foamBaseY = glassRect.maxY - size * 0.04
        let foamPath = NSBezierPath()
        let left = glassRect.minX + size * 0.045
        let right = glassRect.maxX - size * 0.045
        let top = glassRect.maxY + size * 0.02

        foamPath.move(to: CGPoint(x: left, y: foamBaseY))
        foamPath.curve(
            to: CGPoint(x: left + size * 0.10, y: top),
            controlPoint1: CGPoint(x: left - size * 0.005, y: top - size * 0.03),
            controlPoint2: CGPoint(x: left + size * 0.03, y: top + size * 0.035)
        )
        foamPath.curve(
            to: CGPoint(x: rect.midX, y: top + size * 0.004),
            controlPoint1: CGPoint(x: left + size * 0.16, y: top + size * 0.06),
            controlPoint2: CGPoint(x: rect.midX - size * 0.09, y: top + size * 0.02)
        )
        foamPath.curve(
            to: CGPoint(x: right - size * 0.10, y: top),
            controlPoint1: CGPoint(x: rect.midX + size * 0.08, y: top - size * 0.02),
            controlPoint2: CGPoint(x: right - size * 0.16, y: top + size * 0.05)
        )
        foamPath.curve(
            to: CGPoint(x: right, y: foamBaseY),
            controlPoint1: CGPoint(x: right - size * 0.04, y: top + size * 0.035),
            controlPoint2: CGPoint(x: right + size * 0.002, y: top - size * 0.03)
        )
        foamPath.line(to: CGPoint(x: right, y: foamBaseY - size * 0.02))
        foamPath.curve(
            to: CGPoint(x: left, y: foamBaseY - size * 0.02),
            controlPoint1: CGPoint(x: right - size * 0.07, y: foamBaseY - size * 0.06),
            controlPoint2: CGPoint(x: left + size * 0.07, y: foamBaseY - size * 0.06)
        )
        foamPath.close()

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -size * 0.008),
            blur: size * 0.018,
            color: NSColor(calibratedWhite: 0.6, alpha: 0.24).cgColor
        )
        context.setFillColor(NSColor(calibratedWhite: 0.98, alpha: 1).cgColor)
        context.addPath(foamPath.cgPath)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.76).cgColor)
        context.setLineWidth(size * 0.01)
        context.addPath(foamPath.cgPath)
        context.strokePath()
        context.restoreGState()
    }

    private func drawHighlights(in context: CGContext) {
        context.saveGState()

        let rimHighlight = NSBezierPath()
        rimHighlight.move(to: CGPoint(x: glassRect.minX + size * 0.02, y: glassRect.maxY - size * 0.01))
        rimHighlight.curve(
            to: CGPoint(x: glassRect.maxX - size * 0.02, y: glassRect.maxY - size * 0.01),
            controlPoint1: CGPoint(x: glassRect.minX + size * 0.14, y: glassRect.maxY + size * 0.035),
            controlPoint2: CGPoint(x: glassRect.maxX - size * 0.14, y: glassRect.maxY + size * 0.035)
        )
        context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.28).cgColor)
        context.setLineWidth(size * 0.012)
        context.addPath(rimHighlight.cgPath)
        context.strokePath()

        let sparkleRect = CGRect(
            x: size * 0.70,
            y: size * 0.70,
            width: size * 0.10,
            height: size * 0.10
        )
        let sparklePath = NSBezierPath()
        sparklePath.move(to: CGPoint(x: sparkleRect.midX, y: sparkleRect.maxY))
        sparklePath.line(to: CGPoint(x: sparkleRect.midX, y: sparkleRect.minY))
        sparklePath.move(to: CGPoint(x: sparkleRect.minX, y: sparkleRect.midY))
        sparklePath.line(to: CGPoint(x: sparkleRect.maxX, y: sparkleRect.midY))
        context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.65).cgColor)
        context.setLineWidth(size * 0.01)
        context.setLineCap(.round)
        context.addPath(sparklePath.cgPath)
        context.strokePath()

        context.restoreGState()
    }

    private func roundedRect(insetBy inset: CGFloat, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(
            roundedRect: rect.insetBy(dx: inset, dy: inset),
            xRadius: radius,
            yRadius: radius
        )
    }
}

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for index in 0 ..< elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let data = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "GenerateAppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG data."])
    }

    try data.write(to: url)
}

let arguments = CommandLine.arguments
let outputDirectoryURL: URL

if arguments.count > 1 {
    outputDirectoryURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
} else {
    outputDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
}

let iconSizes = [16, 32, 64, 128, 256, 512, 1024]

for dimension in iconSizes {
    let renderer = IconRenderer(size: CGFloat(dimension))
    let image = renderer.render()
    let outputURL = outputDirectoryURL.appendingPathComponent("AppIcon-\(dimension).png")
    try writePNG(image, to: outputURL)
    print("Wrote \(outputURL.path)")
}
