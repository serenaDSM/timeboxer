import AppKit

private final class ShieldWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class ShieldWindowController: NSWindowController {
    var onEarnTime: (() -> Void)?
    var onAskParent: (() -> Void)?

    private let titleLabel = NSTextField(wrappingLabelWithString: "TIME IS UP")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let applicationLabel = NSTextField(labelWithString: "")

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

    func show(applicationName: String, reason: BlockReason) {
        guard let window else { return }
        titleLabel.stringValue = reason.title.uppercased()
        detailLabel.stringValue = reason.detail
        applicationLabel.stringValue = "\(applicationName) is paused by your family plan."
        if let screen = NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showDemo() {
        show(applicationName: "Demo game", reason: .dailyLimitReached)
    }

    @objc private func earnTime() {
        orderOutAndNotify(onEarnTime)
    }

    @objc private func askParent() {
        orderOutAndNotify(onAskParent)
    }

    @objc private func returnToHomework() {
        window?.orderOut(nil)
    }

    private func orderOutAndNotify(_ callback: (() -> Void)?) {
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
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedRed: 0.025, green: 0.035, blue: 0.06, alpha: 1).cgColor

        let badge = NSTextField(labelWithString: "TIMEBOXER · FAMILY PLAN")
        badge.font = .systemFont(ofSize: 13, weight: .bold)
        badge.textColor = .systemBlue
        badge.alignment = .center

        titleLabel.font = .systemFont(ofSize: 40, weight: .black)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.preferredMaxLayoutWidth = 620

        applicationLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        applicationLabel.textColor = NSColor(calibratedWhite: 0.75, alpha: 1)
        applicationLabel.alignment = .center

        detailLabel.font = .systemFont(ofSize: 16, weight: .regular)
        detailLabel.textColor = NSColor(calibratedWhite: 0.6, alpha: 1)
        detailLabel.alignment = .center
        detailLabel.maximumNumberOfLines = 3
        detailLabel.preferredMaxLayoutWidth = 520

        let earnButton = makeButton("Earn more time", action: #selector(earnTime), primary: true)
        let askButton = makeButton("Ask parent for 10 minutes", action: #selector(askParent), primary: false)
        let homeworkButton = makeButton("Return to homework", action: #selector(returnToHomework), primary: false)

        let stack = NSStackView(views: [badge, titleLabel, applicationLabel, detailLabel, earnButton, askButton, homeworkButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 620),
            titleLabel.widthAnchor.constraint(equalToConstant: 620),
            earnButton.widthAnchor.constraint(equalToConstant: 320),
            askButton.widthAnchor.constraint(equalToConstant: 320),
            homeworkButton.widthAnchor.constraint(equalToConstant: 320),
        ])
        return root
    }

    private func makeButton(_ title: String, action: Selector, primary: Bool) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = .systemFont(ofSize: 15, weight: .bold)
        button.contentTintColor = primary ? .systemBlue : .white
        return button
    }
}
