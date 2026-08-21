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

guard let context = CGContext(
    data: nil,
    width: canvasSize,
    height: canvasSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colourSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Unable to create icon drawing context.\n", stderr)
    exit(1)
}

// Keep every pixel outside the rounded black tile transparent. Finder and the
// Dock can then show their own background instead of a baked-in white square.
context.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
context.translateBy(x: 0, y: CGFloat(canvasSize))
context.scaleBy(x: 1, y: -1)

let tile = CGPath(
    roundedRect: CGRect(x: 4, y: 4, width: 1016, height: 1016),
    cornerWidth: 224,
    cornerHeight: 224,
    transform: nil
)

let darkStart = CGColor(red: 20 / 255, green: 24 / 255, blue: 30 / 255, alpha: 1)
let darkEnd = CGColor(red: 5 / 255, green: 6 / 255, blue: 9 / 255, alpha: 1)
let backgroundGradient = CGGradient(
    colorsSpace: colourSpace,
    colors: [darkStart, darkEnd] as CFArray,
    locations: [0, 1]
)!

context.saveGState()
context.addPath(tile)
context.clip()
context.drawLinearGradient(
    backgroundGradient,
    start: CGPoint(x: 120, y: 80),
    end: CGPoint(x: 900, y: 960),
    options: []
)
context.restoreGState()

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
