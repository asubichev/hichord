// Usage: swiftc -O scripts/compose-icon.swift -o /tmp/compose && /tmp/compose <drawing.png> Resources/AppIcon.png
// Trim the white margin off the drawing and place it on a white macOS-style rounded tile (1024 canvas).
import AppKit
let args = CommandLine.arguments
let src = NSImage(contentsOfFile: args[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let w = src.width, h = src.height
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
let px = ctx.data!.assumingMemoryBound(to: UInt8.self)
var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h { for x in 0..<w {
    let i = (y * w + x) * 4
    if Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2]) < 600 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
}}
let crop = ctx.makeImage()!.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))!

let S = 1024
let out = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: S * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)   // Apple macOS icon grid
out.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: CGColor(gray: 0, alpha: 0.3))
out.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil))
out.setFillColor(CGColor(gray: 1, alpha: 1)); out.fillPath()
out.setShadow(offset: .zero, blur: 0, color: nil)
let box = tile.insetBy(dx: 120, dy: 120)
let scale = min(box.width / CGFloat(crop.width), box.height / CGFloat(crop.height))
let dw = CGFloat(crop.width) * scale, dh = CGFloat(crop.height) * scale
out.interpolationQuality = .high
out.draw(crop, in: CGRect(x: box.midX - dw / 2, y: box.midY - dh / 2, width: dw, height: dh))
let rep = NSBitmapImageRep(cgImage: out.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
