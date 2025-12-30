//
//  CPMTerminalViewController.swift
//  Core8080
//
//  CP/M Interactive Terminal
//  Provides a terminal interface for running CP/M programs
//

import UIKit

class CPMTerminalViewController: UIViewController {

    // MARK: - UI Components
    let textView = UITextView()
    let toolbar = UIToolbar()

    // MARK: - State
    var isRunning = false
    var emulatorTimer: Timer?
    var outputCheckTimer: Timer?

    // Terminal colors
    let backgroundColor = UIColor.black
    let textColor = UIColor.green
    let cursorColor = UIColor.green

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardToolbar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Register for keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopEmulator()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI Setup

    func setupUI() {
        title = "CP/M Terminal"

        // Configure text view
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.font = UIFont(name: "Menlo", size: 14) ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.isEditable = true
        textView.delegate = self
        textView.tintColor = cursorColor  // Cursor color

        view.addSubview(textView)

        // Constraints
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Add navigation bar buttons
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(closeTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(resetTapped))

        // Initial message
        appendText("CP/M 2.2 Terminal\n")
        appendText("Ready.\n\n")
    }

    func setupKeyboardToolbar() {
        toolbar.sizeToFit()

        // Add special keys for CP/M
        let controlCButton = UIBarButtonItem(title: "^C", style: .plain, target: self, action: #selector(sendControlC))
        let controlZButton = UIBarButtonItem(title: "^Z", style: .plain, target: self, action: #selector(sendControlZ))
        let escButton = UIBarButtonItem(title: "ESC", style: .plain, target: self, action: #selector(sendEscape))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))

        toolbar.items = [controlCButton, controlZButton, escButton, flexSpace, doneButton]
        textView.inputAccessoryView = toolbar
    }

    // MARK: - Emulator Control

    func startEmulator(withProgram hexCode: String, org: UInt16 = 0x0000) {
        // Stop any running emulator
        stopEmulator()

        // Load and reset
        codereset()
        codeload(hexCode, org)

        // Start emulator loop
        isRunning = true
        emulatorTimer = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: true) { [weak self] _ in
            self?.emulatorStep()
        }

        // Start output checking
        outputCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkOutput()
        }
    }

    func stopEmulator() {
        isRunning = false
        emulatorTimer?.invalidate()
        emulatorTimer = nil
        outputCheckTimer?.invalidate()
        outputCheckTimer = nil
    }

    func emulatorStep() {
        guard isRunning else { return }

        // Check if CPU is waiting for input
        if cpm_is_waiting_for_input() != 0 {
            // Don't execute - waiting for user input
            return
        }

        // Execute one instruction
        codestep()
    }

    func checkOutput() {
        // Get any output characters from CP/M
        while true {
            let ch = cpm_get_char()
            if ch == 0 {
                break
            }

            DispatchQueue.main.async { [weak self] in
                self?.handleOutputChar(ch)
            }
        }
    }

    func handleOutputChar(_ ch: UInt8) {
        switch ch {
        case 0x0D:  // Carriage return
            // Just ignore, wait for LF
            break
        case 0x0A:  // Line feed
            appendText("\n")
        case 0x08:  // Backspace
            deleteLastChar()
        case 0x07:  // Bell
            // Could add haptic feedback here
            break
        case 32..<127:  // Printable ASCII
            appendText(String(UnicodeScalar(ch)))
        default:
            // Show non-printable as hex
            appendText(String(format: "[%02X]", ch))
        }
    }

    // MARK: - Text Management

    func appendText(_ text: String) {
        textView.text.append(text)
        scrollToBottom()
    }

    func deleteLastChar() {
        if !textView.text.isEmpty {
            textView.text.removeLast()
        }
    }

    func scrollToBottom() {
        let range = NSRange(location: textView.text.count, length: 0)
        textView.scrollRangeToVisible(range)
    }

    // MARK: - Actions

    @objc func closeTapped() {
        dismiss(animated: true)
    }

    @objc func resetTapped() {
        stopEmulator()
        codereset()
        textView.text = ""
        appendText("CP/M 2.2 Terminal\n")
        appendText("System Reset.\n\n")
    }

    @objc func sendControlC() {
        cpm_put_char(0x03)  // ^C (ETX)
    }

    @objc func sendControlZ() {
        cpm_put_char(0x1A)  // ^Z (EOF)
    }

    @objc func sendEscape() {
        cpm_put_char(0x1B)  // ESC
    }

    @objc func dismissKeyboard() {
        textView.resignFirstResponder()
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        // Adjust view if needed
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        // Restore view if needed
    }
}

// MARK: - UITextViewDelegate

extension CPMTerminalViewController: UITextViewDelegate {

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {

        // Handle return key
        if text == "\n" {
            cpm_put_char(0x0D)  // Send CR to CP/M
            return false  // Don't add newline to text view (CP/M will echo it)
        }

        // Send each character to CP/M
        for char in text {
            if let ascii = char.asciiValue {
                // Convert lowercase to uppercase for CP/M
                let cpChar = (ascii >= 97 && ascii <= 122) ? ascii - 32 : ascii
                cpm_put_char(cpChar)
            }
        }

        // Don't add to text view - CP/M will echo it
        return false
    }

    func textViewDidChange(_ textView: UITextView) {
        scrollToBottom()
    }
}
