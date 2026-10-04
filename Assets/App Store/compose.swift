#!/usr/bin/env swift

import AppKit

let canvasSize = NSSize(width: 1242, height: 2688)
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let languages = ["en", "ja"]

struct Copy {
    let header: String
    let caption: String
}

struct Screenshot {
    let rawName: String
    let outName: String
    let copy: [String: Copy]
    let gradientTop: NSColor
    let gradientBottom: NSColor
}

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

let fundseeTop = color(0x2E6800)
let fundseeBottom = color(0x16290B)

let screenshots: [Screenshot] = [
    Screenshot(
        rawName: "today",
        outName: "01-today",
        copy: [
            "en": Copy(header: "Know what's left today", caption: "Tap a category to record what you spend"),
            "ja": Copy(header: "今日あといくら使える？", caption: "カテゴリをタップして支出を記録"),
        ],
        gradientTop: fundseeTop, gradientBottom: fundseeBottom
    ),
    Screenshot(
        rawName: "onboarding-1",
        outName: "02-plans",
        copy: [
            "en": Copy(header: "Plan your days", caption: "Budgets for office days, home days, and days off"),
            "ja": Copy(header: "1日を計画", caption: "出社の日、在宅の日、休みの日ごとに予算を"),
        ],
        gradientTop: fundseeTop, gradientBottom: fundseeBottom
    ),
    Screenshot(
        rawName: "onboarding-2",
        outName: "03-week-plan",
        copy: [
            "en": Copy(header: "Plan your week", caption: "Assign a plan to each weekday, just once"),
            "ja": Copy(header: "1週間を計画", caption: "曜日ごとにプランを一度割り当てるだけ"),
        ],
        gradientTop: fundseeTop, gradientBottom: fundseeBottom
    ),
    Screenshot(
        rawName: "week",
        outName: "04-week",
        copy: [
            "en": Copy(header: "Track your week", caption: "Every day's budget and spending side by side"),
            "ja": Copy(header: "1週間をふり返る", caption: "毎日の予算と支出を並べて確認"),
        ],
        gradientTop: fundseeTop, gradientBottom: fundseeBottom
    ),
    Screenshot(
        rawName: "month",
        outName: "05-month",
        copy: [
            "en": Copy(header: "Plan your month", caption: "Week by week progress against the month"),
            "ja": Copy(header: "1ヶ月を計画", caption: "月の予算に対する進み具合を週ごとに"),
        ],
        gradientTop: fundseeTop, gradientBottom: fundseeBottom
    ),
    Screenshot(
        rawName: "year",
        outName: "06-year",
        copy: [
            "en": Copy(header: "See your whole year", caption: "How every month turned out, at a glance"),
            "ja": Copy(header: "1年をひと目で", caption: "毎月の結果を一覧で確認"),
        ],
        gradientTop: fundseeTop, gradientBottom: fundseeBottom
    ),
    Screenshot(
        rawName: "onboarding-3",
        outName: "07-leftovers",
        copy: [
            "en": Copy(header: "Plan to save", caption: "Choose what happens to leftover budget"),
            "ja": Copy(header: "貯金を計画", caption: "残った予算の扱いを選べる"),
        ],
        gradientTop: fundseeTop, gradientBottom: fundseeBottom
    ),
]

// MARK: - Fonts


@discardableResult
func drawLine(
    _ text: String,
    size: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    top: CGFloat,
    maxWidth: CGFloat
) -> CGFloat {
    var fontSize = size
    var attrs: [NSAttributedString.Key: Any] = [:]
    var lineSize = NSSize.zero
    while fontSize > 10 {
        attrs = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color,
        ]
        lineSize = (text as NSString).size(withAttributes: attrs)
        if lineSize.width <= maxWidth { break }
        fontSize -= 2
    }
    (text as NSString).draw(
        at: NSPoint(x: (canvasSize.width - lineSize.width) / 2, y: top - lineSize.height),
        withAttributes: attrs
    )
    return lineSize.height
}

// MARK: - Device frame

let hardwareImage = NSImage(contentsOf: scriptDir.appendingPathComponent("Hardware@2x.png"))!
let displayImage = NSImage(contentsOf: scriptDir.appendingPathComponent("Display@2x.png"))!

func cgImage(of image: NSImage) -> CGImage {
    image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

let hardwareCG = cgImage(of: hardwareImage)
let displayCG = cgImage(of: displayImage)
let hardwarePixel = NSSize(width: hardwareCG.width, height: hardwareCG.height)
let displayPixel = NSSize(width: displayCG.width, height: displayCG.height)
let displayOrigin = NSPoint(
    x: (hardwarePixel.width - displayPixel.width) / 2,
    y: (hardwarePixel.height - displayPixel.height) / 2
)

func maskedScreen(raw: NSImage) -> NSImage {
    let rawCG = cgImage(of: raw)
    let image = NSImage(size: hardwarePixel)
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let displayRect = CGRect(origin: displayOrigin, size: displayPixel)
    ctx.clip(to: displayRect, mask: displayCG)

    let rawSize = CGSize(width: rawCG.width, height: rawCG.height)
    let scale = max(displayPixel.width / rawSize.width, displayPixel.height / rawSize.height)
    let drawSize = CGSize(width: rawSize.width * scale, height: rawSize.height * scale)
    let drawRect = CGRect(
        x: displayRect.midX - drawSize.width / 2,
        y: displayRect.midY - drawSize.height / 2,
        width: drawSize.width,
        height: drawSize.height
    )
    ctx.draw(rawCG, in: drawRect)
    image.unlockFocus()
    return image
}

// MARK: - Composition

func compose(_ shot: Screenshot, language: String) -> Bool {
    guard let copy = shot.copy[language] else { return false }
    let rawURL = scriptDir
        .appendingPathComponent("Raw")
        .appendingPathComponent(language)
        .appendingPathComponent("\(shot.rawName).png")
    guard let raw = NSImage(contentsOf: rawURL) else {
        print("missing raw capture: \(rawURL.path)")
        return false
    }

    let image = NSImage(size: canvasSize)
    image.lockFocus()

    NSGradient(starting: shot.gradientTop, ending: shot.gradientBottom)?
        .draw(in: NSRect(origin: .zero, size: canvasSize), angle: -90)

    let textWidth = canvasSize.width - 96
    let headerTop = canvasSize.height - 84
    let headerHeight = drawLine(
        copy.header, size: 88, weight: .bold,
        color: .white, top: headerTop, maxWidth: textWidth
    )
    let captionTop = headerTop - headerHeight - 6
    let captionHeight = drawLine(
        copy.caption, size: 46, weight: .medium,
        color: .white, top: captionTop, maxWidth: textWidth
    )

    let textBottom = captionTop - captionHeight
    let deviceTopMargin: CGFloat = 64
    let deviceBottomMargin: CGFloat = 88
    let availableHeight = textBottom - deviceTopMargin - deviceBottomMargin
    let aspect = hardwarePixel.width / hardwarePixel.height
    var deviceSize = NSSize(width: availableHeight * aspect, height: availableHeight)
    if deviceSize.width > canvasSize.width - 120 {
        deviceSize.width = canvasSize.width - 120
        deviceSize.height = deviceSize.width / aspect
    }
    let deviceRect = NSRect(
        x: ((canvasSize.width - deviceSize.width) / 2).rounded(),
        y: deviceBottomMargin,
        width: deviceSize.width,
        height: deviceSize.height
    )

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
    shadow.shadowBlurRadius = 60
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.set()
    hardwareImage.draw(in: deviceRect)
    NSGraphicsContext.current?.restoreGraphicsState()

    maskedScreen(raw: raw).draw(in: deviceRect)

    image.unlockFocus()

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width), pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return false }
    bitmap.size = canvasSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(origin: .zero, size: canvasSize))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else { return false }
    let outDir = scriptDir.appendingPathComponent(language)
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let outURL = outDir.appendingPathComponent("\(shot.outName).png")
    do {
        try png.write(to: outURL)
        print("wrote \(language)/\(outURL.lastPathComponent)")
        return true
    } catch {
        print("failed to write \(outURL.path): \(error)")
        return false
    }
}

var allOK = true
for language in languages {
    for shot in screenshots {
        allOK = compose(shot, language: language) && allOK
    }
}
exit(allOK ? 0 : 1)
