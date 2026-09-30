//
//  KeyboardViewController.swift
//  RemoKeyboard
//
//  The keyboard extension. Hosts the HTTP/WebSocket relay server and applies the
//  text operations it receives to the focused text field via UITextDocumentProxy.
//

import UIKit
import RemoboardKit

final class KeyboardViewController: UIInputViewController {

    private var server = RemoServer.make(port: UInt16(Settings.shared.port))
    private var serverPort = UInt16(Settings.shared.port)

    private let statusLabel = UILabel()
    private let infoToggleButton = UIButton(type: .system)
    private let urlLabel = UILabel()
    private let urlScroll = UIScrollView()
    private let pinLabel = UILabel()
    private let infoStack = UIStackView()
    private let nextKeyboardButton = UIButton(type: .system)
    private let wordsButton = UIButton(type: .system)
    private let handoffButton = UIButton(type: .system)
    private let returnButton = UIButton(type: .system)
    private let wordsTable = UITableView()

    private var quickWords: [String] = []
    private var contextThrottle = Throttle(interval: 0.08)
    private var serverRunning = false
    private var connectURL: String?
    private var connectedCount = 0
    private var pinEnabled = false
    private var showConnectionInfo = false   // user override to reveal the URLs while connected

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        quickWords = Settings.shared.quickWords
        buildUI()
        configColors()
        updateReturnTitle()
        wireServer()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard hasFullAccess else {
            showFullAccessGuide()
            return
        }
        startServerIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        server.stop()
        serverRunning = false
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        configColors()
        updateReturnTitle()
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        // System light/dark toggled while the keyboard is on screen — re-tint.
        if traitCollection.userInterfaceStyle != previous?.userInterfaceStyle {
            configColors()
        }
    }

    // MARK: Server

    private func wireServer() {
        server.onInbound = { [weak self] message in
            self?.apply(message)
        }
        server.quickWordsProvider = { Settings.shared.quickWords }
        server.onClientCountChanged = { [weak self] count in
            self?.updateStatus(connectedCount: count)
        }
        server.onDiagnostic = { kind, detail in Settings.shared.recordDiagnostic(kind: kind, detail: detail) }
    }

    private func startServerIfNeeded() {
        guard !serverRunning else { return }
        // Port may have been changed in the app since this server was built — rebuild on the
        // new port and re-wire its callbacks.
        let desiredPort = UInt16(Settings.shared.port)
        if desiredPort != serverPort {
            server.stop()
            server = RemoServer.make(port: desiredPort)
            serverPort = desiredPort
            wireServer()
        }
        let requirePIN = Settings.shared.requirePIN
        server.requirePIN = requirePIN
        pinEnabled = requirePIN
        if requirePIN {
            let pin = Self.sessionPIN()
            server.pin = pin
            pinLabel.text = "PIN  \(pin)"
        } else {
            server.pin = ""
        }
        server.start()
        serverRunning = true
        updateURLs()
        updateStatus(connectedCount: 0)
    }

    private func updateURLs() {
        // Enumerate interfaces once, then pick the primary from that list.
        let all = LocalAddresses.ipv4()
        let primary = all.first { $0.interface == "en0" }
            ?? all.first { $0.interface == "pdp_ip0" }
            ?? all.first
        guard let primary else {
            connectURL = nil
            urlLabel.text = NSLocalizedString("WifiNotFound", comment: "")
            return
        }
        connectURL = "http://\(primary.ip):\(serverPort)"
        // Show the primary URL plus any other reachable interfaces as backups, so a user
        // whose computer is only on a secondary network can still find a working address.
        var urls = [connectURL!]
        urls.append(contentsOf: all.filter { $0.ip != primary.ip }.map { "http://\($0.ip):\(serverPort)" })
        urlLabel.numberOfLines = 0
        urlLabel.text = urls.joined(separator: "\n")
    }

    private func updateStatus(connectedCount count: Int) {
        connectedCount = count
        if count == 0 { showConnectionInfo = false }   // back to idle → reveal by default again
        let key = count > 0 ? "StatusConnected" : "StatusWaiting"
        statusLabel.text = NSLocalizedString(key, comment: "")
        updateInfoVisibility()
    }

    /// Once a computer is connected the URL/PIN block is noise, so hide it and offer a button
    /// to bring it back (e.g. to connect another device). While waiting, it's always shown.
    private func updateInfoVisibility() {
        let connected = connectedCount > 0
        let reveal = !connected || showConnectionInfo
        urlScroll.isHidden = !reveal
        pinLabel.isHidden = !(reveal && pinEnabled)
        infoToggleButton.isHidden = !connected
        let symbol = showConnectionInfo ? "chevron.up.circle" : "chevron.down.circle"
        infoToggleButton.setImage(UIImage(systemName: symbol), for: .normal)
        infoToggleButton.accessibilityLabel = NSLocalizedString(showConnectionInfo ? "HideAddress" : "ShowAddress", comment: "")
    }

    @objc private func toggleConnectionInfo() {
        showConnectionInfo.toggle()
        updateInfoVisibility()
    }

    /// Briefly show a message in the status label, then restore the connection status.
    private func flashStatus(_ message: String) {
        // Make sure the status (not the words page) is visible so the message is seen.
        wordsTable.isHidden = true
        infoStack.isHidden = false
        statusLabel.text = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.statusLabel.text == message else { return }
            self.updateStatus(connectedCount: self.connectedCount)
        }
    }

    // MARK: Applying remote operations

    private func apply(_ message: InboundMessage) {
        switch message {
        case .input(let text, _):
            textDocumentProxy.insertText(text)
        case .delete:
            textDocumentProxy.deleteBackward()
        case .move(let dir, _):
            switch dir {
            case .left: textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
            case .right: textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
            case .up: textDocumentProxy.adjustTextPosition(byCharacterOffset: -20)
            case .down: textDocumentProxy.adjustTextPosition(byCharacterOffset: 20)
            }
        case .clipboardSet(let text):
            guard Settings.shared.allowRemoteClipboardWrite else { server.broadcast(.info(message: NSLocalizedString("ClipboardWriteBlocked", comment: ""))); return }
            UIPasteboard.general.string = text
            Settings.shared.rememberClipboard(text)
            Settings.shared.recordDiagnostic(kind: "clipboard", detail: "Remote write accepted (\(text.utf8.count) bytes; content redacted)")
            server.broadcast(.info(message: NSLocalizedString("ClipboardCopiedToPhone", comment: "")))
            return
        case .clipboardGet:
            sendPhoneClipboard()
            return
        case .handoff(let text):
            openHostApp(query: "text", value: text)
            return
        case .setQuickWords(let items):
            Settings.shared.quickWords = items
            quickWords = items
            wordsTable.reloadData()
            server.broadcast(.quickWords(items))   // keep every client in sync
            return
        case .hello, .ping, .unknown:
            break
        }
        broadcastContext()
    }

    /// Reads the phone's clipboard and pushes it to every connected client.
    private func sendPhoneClipboard() {
        guard Settings.shared.allowRemoteClipboardRead else { server.broadcast(.info(message: NSLocalizedString("ClipboardReadBlocked", comment: ""))); return }
        let text = UIPasteboard.general.string ?? ""
        Settings.shared.rememberClipboard(text)
        Settings.shared.recordDiagnostic(kind: "clipboard", detail: "Remote read accepted (\(text.utf8.count) bytes; content redacted)")
        server.broadcast(.clipboard(text: text))
    }

    /// Opens the Remoboard host app via its URL scheme (`remoboard://handoff?<query>=<value>`).
    /// Keyboard extensions can't reach `UIApplication.shared`, so we walk the responder chain
    /// to find the `UIApplication` instance and call the modern `open(_:)` on it. The old trick
    /// of `perform("openURL:")` on whatever responds silently no-ops on current iOS (that
    /// single-argument selector was removed years ago), which is why Handoff did nothing.
    @discardableResult
    private func openHostApp(query: String, value: String) -> Bool {
        let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "remoboard://handoff?\(query)=\(encoded)") else { return false }
        var responder: UIResponder? = self
        while let current = responder {
            if let app = current as? UIApplication {
                app.open(url, options: [:], completionHandler: nil)
                return true
            }
            responder = current.next
        }
        return false
    }

    private func broadcastContext() {
        contextThrottle.run { [weak self] in
            guard let self else { return }
            let before = self.textDocumentProxy.documentContextBeforeInput ?? ""
            let after = self.textDocumentProxy.documentContextAfterInput ?? ""
            self.server.broadcast(.context(before: before, after: after))
        }
    }

    // MARK: Full access

    private func showFullAccessGuide() {
        statusLabel.text = NSLocalizedString("GuideAllowFullAccess", comment: "")
        urlLabel.text = ""
        pinLabel.text = ""
    }

    // MARK: PIN

    // Generated once per extension process and reused, so reconnecting clients (which
    // resend their cached PIN) keep working when the keyboard is dismissed and re-shown.
    private static var cachedPIN: String?
    private static func sessionPIN() -> String {
        if let pin = cachedPIN { return pin }
        let pin = String(format: "%06d", Int.random(in: 0...999_999))
        cachedPIN = pin
        return pin
    }

    // MARK: Appearance

    /// The host text field requests an appearance via `keyboardAppearance`. When it asks for
    /// `.default` (the common case) we follow the system light/dark setting instead of forcing
    /// light — otherwise our black text renders on the dark system keyboard background.
    private var isDarkAppearance: Bool {
        switch textDocumentProxy.keyboardAppearance {
        case .dark: return true
        case .light: return false
        default: return traitCollection.userInterfaceStyle == .dark
        }
    }

    private func configColors() {
        let dark = isDarkAppearance
        let titleColor: UIColor = dark ? .white : .black
        let buttonBg: UIColor = dark ? UIColor(white: 1, alpha: 0.18) : UIColor(white: 0, alpha: 0.08)
        for button in [nextKeyboardButton, wordsButton, handoffButton, returnButton] {
            button.setTitleColor(titleColor, for: .normal)
            button.tintColor = titleColor
            button.backgroundColor = buttonBg
        }
        statusLabel.textColor = titleColor
        urlLabel.textColor = titleColor
        pinLabel.textColor = titleColor
        infoToggleButton.setTitleColor(titleColor, for: .normal)
        infoToggleButton.tintColor = titleColor
    }

    private func updateReturnTitle() {
        let key: String
        switch textDocumentProxy.returnKeyType {
        case .send: key = "Send"
        case .search: key = "Search"
        case .done: key = "Done"
        case .go: key = "Go"
        default: key = "Return"
        }
        returnButton.setTitle(NSLocalizedString(key, comment: ""), for: .normal)
    }

    @objc private func copyConnectURL() {
        guard let url = connectURL, !url.isEmpty else { return }
        UIPasteboard.general.string = url
        server.broadcast(.info(message: NSLocalizedString("ClipboardCopiedToPhone", comment: "")))
    }
}

// MARK: - UITableView

extension KeyboardViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        quickWords.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "word") ?? UITableViewCell(style: .default, reuseIdentifier: "word")
        cell.textLabel?.text = quickWords[indexPath.row]
        cell.textLabel?.textColor = isDarkAppearance ? .white : .black
        cell.backgroundColor = .clear
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        textDocumentProxy.insertText(quickWords[indexPath.row])
        broadcastContext()
    }
}

// MARK: - UI construction

private extension KeyboardViewController {

    func buildUI() {
        view.backgroundColor = .clear

        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textAlignment = .natural        // left-aligned (follows RTL where applicable)
        statusLabel.numberOfLines = 1               // keep it one tidy line — shrink if needed
        statusLabel.adjustsFontSizeToFitWidth = true
        statusLabel.minimumScaleFactor = 0.75
        statusLabel.text = NSLocalizedString("StatusWaiting", comment: "")
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // A compact icon (chevron) to reveal/hide the address block once connected.
        infoToggleButton.isHidden = true
        infoToggleButton.setPreferredSymbolConfiguration(.init(pointSize: 20, weight: .semibold), forImageIn: .normal)
        infoToggleButton.setContentHuggingPriority(.required, for: .horizontal)
        infoToggleButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        infoToggleButton.addTarget(self, action: #selector(toggleConnectionInfo), for: .touchUpInside)

        let statusRow = UIStackView(arrangedSubviews: [statusLabel, infoToggleButton])
        statusRow.axis = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .center

        // One URL per line, left-aligned and full-size (no shrink-to-fit), inside a scroll view
        // capped in height — so when there are many interface addresses you can scroll to see
        // them all instead of them squeezing into illegible centered text.
        urlLabel.font = .monospacedSystemFont(ofSize: 15, weight: .semibold)
        urlLabel.textAlignment = .natural
        urlLabel.numberOfLines = 0
        urlLabel.isUserInteractionEnabled = true
        urlLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyConnectURL)))
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlScroll.addSubview(urlLabel)
        urlScroll.showsVerticalScrollIndicator = true
        let fitHeight = urlScroll.heightAnchor.constraint(equalTo: urlLabel.heightAnchor)
        fitHeight.priority = .defaultHigh           // hug the content…
        let capHeight = urlScroll.heightAnchor.constraint(lessThanOrEqualToConstant: 84)
        NSLayoutConstraint.activate([
            urlLabel.topAnchor.constraint(equalTo: urlScroll.contentLayoutGuide.topAnchor),
            urlLabel.bottomAnchor.constraint(equalTo: urlScroll.contentLayoutGuide.bottomAnchor),
            urlLabel.leadingAnchor.constraint(equalTo: urlScroll.contentLayoutGuide.leadingAnchor),
            urlLabel.trailingAnchor.constraint(equalTo: urlScroll.contentLayoutGuide.trailingAnchor),
            urlLabel.widthAnchor.constraint(equalTo: urlScroll.frameLayoutGuide.widthAnchor),
            fitHeight, capHeight,                    // …but cap it and scroll past the cap
        ])

        pinLabel.font = .monospacedSystemFont(ofSize: 17, weight: .bold)
        pinLabel.textAlignment = .natural

        infoStack.addArrangedSubview(statusRow)
        infoStack.addArrangedSubview(urlScroll)
        infoStack.addArrangedSubview(pinLabel)
        infoStack.axis = .vertical
        infoStack.spacing = 4
        infoStack.alignment = .fill

        configureBarButton(nextKeyboardButton, title: NSLocalizedString("Next", comment: ""))
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        configureBarButton(wordsButton, title: NSLocalizedString("Words", comment: ""))
        wordsButton.addTarget(self, action: #selector(toggleWords), for: .touchUpInside)

        configureBarButton(handoffButton, title: NSLocalizedString("Handoff", comment: ""))
        handoffButton.addTarget(self, action: #selector(tapHandoff), for: .touchUpInside)

        configureBarButton(returnButton, title: NSLocalizedString("Return", comment: ""))
        returnButton.addTarget(self, action: #selector(tapReturn), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [nextKeyboardButton, wordsButton, handoffButton, returnButton])
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 6

        wordsTable.dataSource = self
        wordsTable.delegate = self
        wordsTable.backgroundColor = .clear
        wordsTable.isHidden = true
        wordsTable.rowHeight = 40

        let root = UIStackView(arrangedSubviews: [infoStack, wordsTable, buttonStack])
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            wordsTable.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            buttonStack.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    func configureBarButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15)
        button.layer.cornerRadius = 6
        // Colors (incl. background) are set by configColors() for light/dark appearance.
    }

    @objc func toggleWords() {
        let showWords = wordsTable.isHidden
        quickWords = Settings.shared.quickWords
        wordsTable.reloadData()
        wordsTable.isHidden = !showWords
        // Words and the connection info (URL/PIN) are mutually exclusive pages.
        infoStack.isHidden = showWords
    }

    @objc func tapReturn() {
        textDocumentProxy.insertText("\n")
        broadcastContext()
    }

    // Handoff (Apple Continuity): hand the connection URL to the host app, which publishes
    // it as a browsing-web NSUserActivity. The same URL then shows up in Handoff on your Mac,
    // so you can open the Remoboard web page there and keep typing from the computer.
    @objc func tapHandoff() {
        guard let url = connectURL, !url.isEmpty else {
            flashStatus(NSLocalizedString("WifiNotFound", comment: ""))
            return
        }
        if !openHostApp(query: "url", value: url) {
            flashStatus(NSLocalizedString("HandoffFailed", comment: ""))
        }
    }
}

/// Coalesces rapid calls so we don't flood the socket with context echoes.
final class Throttle {
    private let interval: TimeInterval
    private var lastFire: Date = .distantPast
    init(interval: TimeInterval) { self.interval = interval }
    func run(_ block: () -> Void) {
        let now = Date()
        guard now.timeIntervalSince(lastFire) >= interval else { return }
        lastFire = now
        block()
    }
}
