// Extracts SVG path data for each character of a string from a TTF at a point size,
// using CoreText — the same outlines the app's mask renderer traces. y is flipped to
// SVG's y-down; the origin is the pen position on the baseline.
//
//     swift glyph_paths.swift <font.ttf> <size> "<text>" > glyphs.json
import Foundation
import CoreText
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 4, let size = Double(args[2]) else {
    FileHandle.standardError.write("usage: glyph_paths.swift <font.ttf> <size> <text>\n".data(using: .utf8)!)
    exit(1)
}
let url = URL(fileURLWithPath: args[1]) as CFURL
guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor],
      let descriptor = descriptors.first else {
    FileHandle.standardError.write("could not read font\n".data(using: .utf8)!)
    exit(1)
}
let font = CTFontCreateWithFontDescriptor(descriptor, CGFloat(size), nil)

func fmt(_ v: CGFloat) -> String { String(format: "%.2f", v) }

func svgPath(_ ch: Character) -> String? {
    let utf16 = Array(String(ch).utf16)
    var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
    guard CTFontGetGlyphsForCharacters(font, utf16, &glyphs, utf16.count),
          let glyph = glyphs.first, glyph != 0,
          let path = CTFontCreatePathForGlyph(font, glyph, nil) else { return nil }
    var out = ""
    path.applyWithBlock { element in
        let e = element.pointee
        switch e.type {
        case .moveToPoint:
            out += "M\(fmt(e.points[0].x)) \(fmt(-e.points[0].y))"
        case .addLineToPoint:
            out += "L\(fmt(e.points[0].x)) \(fmt(-e.points[0].y))"
        case .addQuadCurveToPoint:
            out += "Q\(fmt(e.points[0].x)) \(fmt(-e.points[0].y)) \(fmt(e.points[1].x)) \(fmt(-e.points[1].y))"
        case .addCurveToPoint:
            out += "C\(fmt(e.points[0].x)) \(fmt(-e.points[0].y)) \(fmt(e.points[1].x)) \(fmt(-e.points[1].y)) \(fmt(e.points[2].x)) \(fmt(-e.points[2].y))"
        case .closeSubpath:
            out += "Z"
        @unknown default:
            break
        }
    }
    return out
}

var glyphs: [String: String] = [:]
for ch in Set(args[3]) where !ch.isWhitespace {
    if let p = svgPath(ch) { glyphs[String(ch)] = p }
}
let payload: [String: Any] = [
    "font": CTFontCopyPostScriptName(font) as String,
    "size": size,
    "ascent": CTFontGetAscent(font),
    "descent": CTFontGetDescent(font),
    "glyphs": glyphs,
]
let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
