#!/usr/bin/env swift
// App Icon生成: ダークネイビー背景 + 「N」を抽象化した上昇グラフ（白）+ ゴールドのコイン
// usage: swift scripts/generate_app_icon.swift Nareta/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let space = CGColorSpaceCreateDeviceRGB()

// 背景
let bg = CGGradient(colorsSpace: space, colors: [color(0x1C2A4A), color(0x080E1C)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
let glow = CGGradient(colorsSpace: space, colors: [color(0x0A7AFF, 0.35), color(0x0A7AFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 330, y: 300), startRadius: 0, endCenter: CGPoint(x: 330, y: 300), endRadius: 620, options: [])

// N 上昇グラフ
let path = CGMutablePath()
path.move(to: CGPoint(x: 250, y: 240))
path.addLine(to: CGPoint(x: 250, y: 720))
path.addLine(to: CGPoint(x: 560, y: 380))
path.addLine(to: CGPoint(x: 780, y: 700))
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.setLineWidth(96)
ctx.setShadow(offset: .zero, blur: 40, color: color(0x0A7AFF, 0.6))
ctx.setStrokeColor(color(0xFFFFFF))
ctx.addPath(path)
ctx.strokePath()

// 矢印の先端
ctx.setShadow(offset: .zero, blur: 0, color: nil)
let head = CGMutablePath()
head.move(to: CGPoint(x: 850, y: 800))
head.addLine(to: CGPoint(x: 660, y: 770))
head.addLine(to: CGPoint(x: 830, y: 620))
head.closeSubpath()
ctx.setFillColor(color(0xFFFFFF))
ctx.addPath(head)
ctx.fillPath()

// コイン
let coinCenter = CGPoint(x: 770, y: 300)
let coinRadius: CGFloat = 140
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0x000000, 0.45))
ctx.addEllipse(in: CGRect(x: coinCenter.x - coinRadius, y: coinCenter.y - coinRadius, width: coinRadius * 2, height: coinRadius * 2))
ctx.clip()
let gold = CGGradient(colorsSpace: space, colors: [color(0xFBE3A0), color(0xE2B24E), color(0xB8812A)] as CFArray, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(gold, start: CGPoint(x: coinCenter.x, y: coinCenter.y + coinRadius), end: CGPoint(x: coinCenter.x, y: coinCenter.y - coinRadius), options: [])
ctx.restoreGState()
ctx.setStrokeColor(color(0xFFF1C2, 0.8))
ctx.setLineWidth(12)
ctx.strokeEllipse(in: CGRect(x: coinCenter.x - coinRadius + 26, y: coinCenter.y - coinRadius + 26, width: (coinRadius - 26) * 2, height: (coinRadius - 26) * 2))

let yen = NSAttributedString(string: "¥", attributes: [
    .font: NSFont.systemFont(ofSize: 150, weight: .heavy),
    .foregroundColor: NSColor(cgColor: color(0x8A5E17))!,
])
let yenSize = yen.size()
yen.draw(at: CGPoint(x: coinCenter.x - yenSize.width / 2, y: coinCenter.y - yenSize.height / 2))

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")
