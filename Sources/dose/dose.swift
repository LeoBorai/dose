import AVFoundation
import AppKit
import Cocoa

@available(macOS 10.15, *)
@main
struct Dose {
    @available(macOS 10.15, *)
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@available(macOS 10.15, *)
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var popoverController: PopoverViewController!
    var player: AVAudioPlayer?

    private var timer: Timer?
    private var remainingSeconds: Int = 0 {
        didSet {
            updateStatusTitle()
            popoverController.updateDisplay(seconds: remainingSeconds)
        }
    }

    private func notifyFinished() {
        if #available(macOS 11.0, *) {
            let notification = NSUserNotification()
            notification.title = "Time's up!"
            notification.informativeText = "Your dose timer has finished."
            NSUserNotificationCenter.default.deliver(notification)
        } else {
            let notification = NSUserNotification()
            notification.title = "Time's up!"
            notification.informativeText = "Your dose timer has finished."
            NSUserNotificationCenter.default.deliver(notification)
        }
    }

    private func playSound() {
        let url: URL?

        #if DEBUG
            // During development, load from the source tree
            url = URL(fileURLWithPath: "assets/Calm.mp3")
        #else
            url = Bundle.main.url(forResource: "Calm", withExtension: "mp3")
        #endif

        guard let url else {
            print("Sound file not found")
            return
        }

        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60

        return String(format: "%02d:%02d", minutes, secs)
    }

    private func updateStatusTitle() {
        if timer != nil {
            statusItem.button?.title = formatTime(remainingSeconds)
        } else {
            statusItem.button?.title = "Dose"
        }
    }

    private func tick() {
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            timer?.invalidate()
            timer = nil
            playSound()
            notifyFinished()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = 0
    }

    private func startTimer(totalSeconds: Int) {
        stopTimer()
        guard totalSeconds > 0 else { return }
        remainingSeconds = totalSeconds
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        popover = NSPopover()
        popoverController = PopoverViewController()
        popover.contentViewController = popoverController
        popover.behavior = .transient
        popover.delegate = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Dose")
                button.image?.isTemplate = true
            } else {
                button.title = "Dose"
            }

            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popoverController.onStart = { [weak self] totalSeconds in
            self?.startTimer(totalSeconds: totalSeconds)
        }

        popoverController.onStop = { [weak self] in
            self?.stopTimer()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@available(macOS 10.15, *)
class PopoverViewController: NSViewController {
    var onStart: ((Int) -> Void)?
    var onStop: (() -> Void)?

    let hoursField = NSTextField()
    let minutesField = NSTextField()
    let secondsField = NSTextField()
    let startButton = NSButton()
    let stopButton = NSButton()
    let timeLabel = NSTextField(labelWithString: "00:00")

    override func loadView() {
        let w: CGFloat = 280
        let h: CGFloat = 160
        let view = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        self.view = view

        // HH:MM:SS fields
        let colonSpacing: CGFloat = 10
        let fieldW: CGFloat = 50
        let fieldH: CGFloat = 30
        let topY = h - 55
        let startX: CGFloat = 20

        func makeField() -> NSTextField {
            let f = NSTextField()
            f.placeholderString = "00"
            f.alignment = .center
            f.formatter = OnlyIntegerValueFormatter()
            f.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
            return f
        }

        func makeColon(x: CGFloat) -> NSTextField {
            let l = NSTextField(labelWithString: ":")
            l.frame = NSRect(x: x, y: topY + 3, width: 10, height: fieldH)
            l.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
            return l
        }

        func makeLabel(_ text: String, x: CGFloat) -> NSTextField {
            let l = NSTextField(labelWithString: text)
            l.frame = NSRect(x: x, y: topY - 18, width: fieldW, height: 16)
            l.alignment = .center
            l.font = NSFont.systemFont(ofSize: 10)
            l.textColor = .secondaryLabelColor
            return l
        }

        let col1X = startX
        let colon1X = col1X + fieldW + 2
        let col2X = colon1X + colonSpacing
        let colon2X = col2X + fieldW + 2
        let col3X = colon2X + colonSpacing

        hoursField.frame = NSRect(x: col1X, y: topY, width: fieldW, height: fieldH)
        minutesField.frame = NSRect(x: col2X, y: topY, width: fieldW, height: fieldH)
        secondsField.frame = NSRect(x: col3X, y: topY, width: fieldW, height: fieldH)

        for f in [hoursField, minutesField, secondsField] {
            let field = makeField()
            f.placeholderString = field.placeholderString
            f.alignment = field.alignment
            f.formatter = field.formatter
            f.font = field.font
            view.addSubview(f)
        }

        view.addSubview(makeColon(x: colon1X))
        view.addSubview(makeColon(x: colon2X))
        view.addSubview(makeLabel("HH", x: col1X))
        view.addSubview(makeLabel("MM", x: col2X))
        view.addSubview(makeLabel("SS", x: col3X))

        timeLabel.frame = NSRect(x: 20, y: h - 95, width: 240, height: 24)
        timeLabel.alignment = .center
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        view.addSubview(timeLabel)

        startButton.frame = NSRect(x: 20, y: 20, width: 110, height: 30)
        startButton.title = "Start"
        startButton.bezelStyle = .rounded
        startButton.action = #selector(startTapped(_:))
        startButton.target = self
        view.addSubview(startButton)

        stopButton.frame = NSRect(x: 145, y: 20, width: 110, height: 30)
        stopButton.title = "Stop"
        stopButton.bezelStyle = .rounded
        stopButton.action = #selector(stopTapped(_:))
        stopButton.target = self
        view.addSubview(stopButton)
    }

    @objc func startTapped(_ sender: Any) {
        let minutes =
            Int(minutesField.stringValue) ?? Int(minutesField.placeholderString ?? "") ?? 0
        let totalSeconds = max(0, minutes * 60)

        if totalSeconds > 0 {
            onStart?(totalSeconds)
        }
    }

    @objc func stopTapped(_ sender: Any) {
        onStop?()
        updateDisplay(seconds: 0)
    }

    func updateDisplay(seconds: Int) {
        let minutes = seconds / 60
        let secs = seconds % 60
        timeLabel.stringValue = String(format: "%02d:%02d", minutes, secs)
    }
}

@available(macOS 10.15, *)
class OnlyIntegerValueFormatter: NumberFormatter, @unchecked Sendable {
    override init() {
        super.init()
        self.allowsFloats = false
        self.minimum = 0
        self.numberStyle = .none
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func isPartialStringValid(
        _ partialString: String, newEditingString: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
        errorDescription: AutoreleasingUnsafeMutablePointer<AnyObject?>?
    ) -> Bool {
        if partialString.isEmpty {
            return true
        }

        return Int(partialString) != nil
    }
}
