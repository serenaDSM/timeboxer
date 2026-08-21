#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

private let canvasSize = 1024

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-app-icon.swift <output.png>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let colourSpace = CGColorSpaceCreateDeviceRGB()
let bytesPerPixel = 4
let bytesPerRow = canvasSize * bytesPerPixel
let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: canvasSize * bytesPerRow)
pixels.initialize(repeating: 0, count: canvasSize * bytesPerRow)
defer { pixels.deallocate() }

guard let context = CGContext(
    data: pixels,
    width: canvasSize,
    height: canvasSize,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colourSpace,
    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Unable to create icon drawing context.\n", stderr)
    exit(1)
}

// Create the rounded tile as an explicit signed-distance alpha mask. This
// guarantees four identical corners and keeps every exterior pixel transparent,
// without relying on SDK-dependent rounded-path clipping.
let tileCentre = Double(canvasSize) / 2
let tileHalfSize = 508.0
let cornerRadius = 224.0
let innerHalfSize = tileHalfSize - cornerRadius

for row in 0..<canvasSize {
    for column in 0..<canvasSize {
        let x = Double(column) + 0.5
        let y = Double(row) + 0.5
        let qx = abs(x - tileCentre) - innerHalfSize
        let qy = abs(y - tileCentre) - innerHalfSize
        let outsideDistance = hypot(max(qx, 0), max(qy, 0))
        let insideDistance = min(max(qx, qy), 0)
        let signedDistance = outsideDistance + insideDistance - cornerRadius
        let coverage = min(max(0.5 - signedDistance, 0), 1)
        guard coverage > 0 else { continue }

        let gradient = min(max((x + (Double(canvasSize) - y)) / (Double(canvasSize) * 2), 0), 1)
        let red = 20.0 + (5.0 - 20.0) * gradient
        let green = 24.0 + (6.0 - 24.0) * gradient
        let blue = 30.0 + (9.0 - 30.0) * gradient
        let offset = row * bytesPerRow + column * bytesPerPixel
        pixels[offset] = UInt8((red * coverage).rounded())
        pixels[offset + 1] = UInt8((green * coverage).rounded())
        pixels[offset + 2] = UInt8((blue * coverage).rounded())
        pixels[offset + 3] = UInt8((255 * coverage).rounded())
    }
}

// The cube coordinates originate in the SVG's top-left coordinate system.
// Flip only the cube drawing, after the rounded tile has been rendered in the
// native Core Graphics coordinate system.
context.translateBy(x: 0, y: CGFloat(canvasSize))
context.scaleBy(x: 1, y: -1)

let cube = CGMutablePath()
cube.move(to: CGPoint(x: 512, y: 245))
cube.addLine(to: CGPoint(x: 746, y: 382))
cube.addLine(to: CGPoint(x: 746, y: 642))
cube.addLine(to: CGPoint(x: 512, y: 779))
cube.addLine(to: CGPoint(x: 278, y: 642))
cube.addLine(to: CGPoint(x: 278, y: 382))
cube.closeSubpath()

cube.move(to: CGPoint(x: 289, y: 389))
cube.addLine(to: CGPoint(x: 512, y: 519))
cube.addLine(to: CGPoint(x: 735, y: 389))
cube.move(to: CGPoint(x: 512, y: 519))
cube.addLine(to: CGPoint(x: 512, y: 779))

let neonGreen = CGColor(red: 53 / 255, green: 243 / 255, blue: 47 / 255, alpha: 1)
let glowGreen = CGColor(red: 53 / 255, green: 213 / 255, blue: 50 / 255, alpha: 0.42)

func strokeCube(shadow: CGColor?) {
    context.saveGState()
    context.setLineWidth(54)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(neonGreen)
    if let shadow {
        context.setShadow(offset: .zero, blur: 18, color: shadow)
    }
    context.addPath(cube)
    context.strokePath()
    context.restoreGState()
}

strokeCube(shadow: glowGreen)
strokeCube(shadow: nil)

guard let image = context.makeImage() else {
    fputs("Unable to render icon image.\n", stderr)
    exit(1)
}

let bitmap = NSBitmapImageRep(cgImage: image)
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode icon as PNG.\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try pngData.write(to: outputURL, options: .atomic)
