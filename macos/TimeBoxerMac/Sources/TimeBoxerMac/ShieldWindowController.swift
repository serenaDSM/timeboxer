import AppKit

private final class ShieldWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class ShieldBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSGradient(colors: [
            NSColor(calibratedRed: 0.055, green: 0.065, blue: 0.075, alpha: 1),
            NSColor(calibratedRed: 0.018, green: 0.021, blue: 0.026, alpha: 1),
        ])
        background?.draw(in: bounds, angle: -90)

        let glowRect = NSRect(
            x: bounds.midX - 360,
            y: bounds.midY - 300,
            width: 720,
            height: 600
        )
        NSColor(calibratedRed: 0.20, green: 0.84, blue: 0.20, alpha: 0.035).setFill()
        NSBezierPath(ovalIn: glowRect).fill()
    }
}

private final class BrandMarkView: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: 64, height: 64) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let tile = bounds.insetBy(dx: 1, dy: 1)
        let tilePath = NSBezierPath(roundedRect: tile, xRadius: 17, yRadius: 17)
        NSColor(calibratedRed: 0.035, green: 0.043, blue: 0.051, alpha: 1).setFill()
        tilePath.fill()
        NSColor(calibratedRed: 0.14, green: 0.18, blue: 0.16, alpha: 1).setStroke()
        tilePath.lineWidth = 1
        tilePath.stroke()

        let scaleX = bounds.width / 64
        let scaleY = bounds.height / 64
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: x * scaleX, y: y * scaleY)
        }

        let cube = NSBezierPath()
        cube.move(to: point(32, 49))
        cube.line(to: point(49, 39))
        cube.line(to: point(49, 20))
        cube.line(to: point(32, 10))
        cube.line(to: point(15, 20))
        cube.line(to: point(15, 39))
        cube.close()
        cube.move(to: point(16, 39))
        cube.line(to: point(32, 30))
        cube.line(to: point(48, 39))
        cube.move(to: point(32, 30))
        cube.line(to: point(32, 10))

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 0.22, green: 1, blue: 0.08, alpha: 0.34)
        shadow.shadowBlurRadius = 9
        shadow.shadowOffset = .zero
        shadow.set()
        NSColor(calibratedRed: 0.22, green: 1, blue: 0.08, alpha: 1).setStroke()
        cube.lineWidth = 4.2
        cube.lineCapStyle = .round
        cube.lineJoinStyle = .round
        cube.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}

@MainActor
final class ShieldWindowController: NSWindowController {
    var onEarnTime: (() -> Void)?
    var onAskParent: (() -> Void)?
    var onReturnToHomework: (() -> Void)?

    private let titleLabel = NSTextField(wrappingLabelWithString: "TIME IS UP")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let applicationLabel = NSTextField(labelWithString: "")
    private let alarmPlayer = FocusAlarmPlayer()

    init() {
        let initialFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let window = ShieldWindow(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        configureWindow(window)
        window.contentView = makeContentView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(applicationName: String, reason: BlockReason, mode: EnforcementMode) {
        guard let window else { return }
        if mode.shouldTerminateEntertainment {
            titleLabel.stringValue = reason.title.uppercased()
            detailLabel.stringValue = reason.detail
            applicationLabel.stringValue = "\(applicationName) is paused by your family plan."
        } else {
            titleLabel.stringValue = "PLAY TIME IS NOT ACTIVE"
            detailLabel.stringValue = "This screen stays protected until you return to TimeBoxer, earn time, or ask your parent. The app remains open in the background."
            applicationLabel.stringValue = "\(applicationName) triggered the family focus shield."
        }
        if let screen = NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }
        alarmPlayer.start()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showDemo() {
        show(applicationName: "Demo game", reason: .dailyLimitReached, mode: .observe)
    }

    @objc private func earnTime() {
        orderOutAndNotify(onEarnTime)
    }

    @objc private func askParent() {
        orderOutAndNotify(onAskParent)
    }

    @objc private func returnToHomework() {
        orderOutAndNotify(onReturnToHomework)
    }

    private func orderOutAndNotify(_ callback: (() -> Void)?) {
        alarmPlayer.stop()
        window?.orderOut(nil)
        callback?()
    }

    private func configureWindow(_ window: NSWindow) {
        window.level = .screenSaver
        window.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 0.98)
        window.isOpaque = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    private func makeContentView() -> NSView {
        let root = ShieldBackgroundView()

        let logo = BrandMarkView()
        logo.translatesAutoresizingMaskIntoConstraints = false

        let wordmark = NSTextField(labelWithAttributedString: makeWordmark())
        wordmark.alignment = .left

        let brand = NSStackView(views: [logo, wordmark])
        brand.orientation = .horizontal
        brand.alignment = .centerY
        brand.spacing = 16

        let badge = NSTextField(labelWithString: "●  FAMILY PLAN ACTIVE")
        badge.font = .systemFont(ofSize: 12, weight: .bold)
        badge.textColor = brandGreen
        badge.alignment = .center

        titleLabel.font = .systemFont(ofSize: 44, weight: .black)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.preferredMaxLayoutWidth = 620

        applicationLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        applicationLabel.textColor = NSColor(calibratedWhite: 0.86, alpha: 1)
        applicationLabel.alignment = .center

        detailLabel.font = .systemFont(ofSize: 16, weight: .regular)
        detailLabel.textColor = NSColor(calibratedWhite: 0.58, alpha: 1)
        detailLabel.alignment = .center
        detailLabel.maximumNumberOfLines = 3
        detailLabel.preferredMaxLayoutWidth = 520

        let earnButton = makeButton("Earn more time", action: #selector(earnTime), primary: true)
        let askButton = makeButton("Ask parent for 10 minutes", action: #selector(askParent), primary: false)
        let homeworkButton = makeButton("Return to TimeBoxer", action: #selector(returnToHomework), primary: false)

        let messageStack = NSStackView(views: [titleLabel, applicationLabel, detailLabel])
        messageStack.orientation = .vertical
        messageStack.alignment = .centerX
        messageStack.spacing = 12

        let buttonStack = NSStackView(views: [earnButton, askButton, homeworkButton])
        buttonStack.orientation = .vertical
        buttonStack.alignment = .centerX
        buttonStack.spacing = 12

        let stack = NSStackView(views: [brand, badge, messageStack, buttonStack])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false

        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor(calibratedRed: 0.045, green: 0.05, blue: 0.06, alpha: 0.92).cgColor
        panel.layer?.cornerRadius = 30
        panel.layer?.borderWidth = 1
        panel.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.08).cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        root.addSubview(panel)

        NSLayoutConstraint.activate([
            logo.widthAnchor.constraint(equalToConstant: 64),
            logo.heightAnchor.constraint(equalToConstant: 64),
            panel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 720),
            panel.topAnchor.constraint(greaterThanOrEqualTo: root.topAnchor, constant: 32),
            panel.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 44),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -44),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 50),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -50),
            titleLabel.widthAnchor.constraint(equalToConstant: 620),
            earnButton.widthAnchor.constraint(equalToConstant: 360),
            askButton.widthAnchor.constraint(equalToConstant: 360),
            homeworkButton.widthAnchor.constraint(equalToConstant: 360),
            earnButton.heightAnchor.constraint(equalToConstant: 48),
            askButton.heightAnchor.constraint(equalToConstant: 48),
            homeworkButton.heightAnchor.constraint(equalToConstant: 48),
        ])
        return root
    }

    private func makeButton(_ title: String, action: Selector, primary: Bool) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 13
        button.layer?.backgroundColor = primary
            ? brandGreen.cgColor
            : NSColor(calibratedWhite: 1, alpha: 0.075).cgColor
        button.layer?.borderWidth = primary ? 0 : 1
        button.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.12).cgColor
        button.font = .systemFont(ofSize: 15, weight: .bold)
        button.contentTintColor = primary
            ? NSColor(calibratedWhite: 0.035, alpha: 1)
            : .white
        return button
    }

    private var brandGreen: NSColor {
        NSColor(calibratedRed: 0.21, green: 0.84, blue: 0.20, alpha: 1)
    }

    private func makeWordmark() -> NSAttributedString {
        let baseFont = NSFont.systemFont(ofSize: 27, weight: .black)
        let font = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        let result = NSMutableAttributedString(
            string: "TIME",
            attributes: [
                .font: font,
                .foregroundColor: NSColor(calibratedWhite: 0.68, alpha: 1),
                .kern: -0.7,
            ]
        )
        result.append(NSAttributedString(
            string: "BOXER",
            attributes: [
                .font: font,
                .foregroundColor: brandGreen,
                .kern: -0.7,
            ]
        ))
        return result
    }
}
