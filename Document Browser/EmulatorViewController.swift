//
//  EmulatorViewController.swift
//  Core8080
//
//  Created by John Kennedy on 4/28/19.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit

class EmulatorViewController: UIViewController {

    
    var timer: Timer?
    var running = false
    var currentOpcode = ""
    var nextOpcode = ""
    
    let CPU = Assemble()
    var sourceCode : String = ""
    var assemblerOutput : String = ""
    var octalOutput : String = ""
    var hexOutput : String = ""
    var orgAddress : UInt16 = 0


    // Blinkenlights
    
    @IBOutlet weak var led_a0: UIImageView!
    @IBOutlet weak var led_a1: UIImageView!
    @IBOutlet weak var led_a2: UIImageView!
    @IBOutlet weak var led_a3: UIImageView!
    @IBOutlet weak var led_a4: UIImageView!
    @IBOutlet weak var led_a5: UIImageView!
    @IBOutlet weak var led_a6: UIImageView!
    @IBOutlet weak var led_a7: UIImageView!
    
    @IBOutlet weak var led_a8: UIImageView!
    @IBOutlet weak var led_a9: UIImageView!
    @IBOutlet weak var led_a10: UIImageView!
    @IBOutlet weak var led_a11: UIImageView!
    @IBOutlet weak var led_a12: UIImageView!
    @IBOutlet weak var led_a13: UIImageView!
    @IBOutlet weak var led_a14: UIImageView!
    @IBOutlet weak var led_a15: UIImageView!
    
    @IBOutlet weak var led_wait: UIImageView!
    
    @IBOutlet weak var led_d0: UIImageView!
    @IBOutlet weak var led_d1: UIImageView!
    @IBOutlet weak var led_d2: UIImageView!
    @IBOutlet weak var led_d3: UIImageView!
    @IBOutlet weak var led_d4: UIImageView!
    @IBOutlet weak var led_d5: UIImageView!
    @IBOutlet weak var led_d6: UIImageView!
    @IBOutlet weak var led_d7: UIImageView!
    
    @IBOutlet weak var labelRegisters: UILabel!
    @IBOutlet weak var textViewSourceCode: UITextView!

    @IBOutlet weak var viewAltair: UIView!
    @IBOutlet weak var runButton: UIButton!
    @IBOutlet weak var stepButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!

    var consoleOutput: String = ""
    
    @IBAction func tapDone(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func highlightCurrentOpcode(_ pc : UInt16)
    {
        // Display the current instruction by finding the address in the assembly listing
        // and putting a > at the start of the line.
        let hexPC = (String(format :"%04X:", pc) + " ")
        let text = assemblerOutput.replacingOccurrences(of: hexPC, with: String(format :"%04X:", pc) + ">")
        textViewSourceCode.text = text
    }

    
    @IBAction func tapReset(_ sender: Any) {
        labelRegisters.text = String(cString: codereset())
        highlightCurrentOpcode(0)
        led_wait.isHidden = false
        stepButton.isEnabled = true
        updateBlinkenlights()
    }
    
    @IBAction func tapRun(_ sender: Any) {
        if running
        {
            led_wait.isHidden = false
            runButton.setTitle("Run", for: .normal)
            running = false
            timer!.invalidate()
            stepButton.isEnabled = true
            resetButton.isEnabled = true
        }
        else
        {
            led_wait.isHidden = true
             stepButton.isEnabled = false
            resetButton.isEnabled = false
            runButton.setTitle("Stop", for: .normal)
            running = true
            timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        }
        
     }
    
    @objc func fireTimer() {
        let temp = currentAddress()
         coderun()
        highlightCurrentOpcode(UInt16(currentAddress()))
        updateBlinkenlights()

        // Poll for CP/M console output
        updateConsoleOutput()

        // Check to see if we should stop..
        if temp == currentAddress() || currentAddress() > 65536
        {
            tapRun(self)
        }
    }

    func updateConsoleOutput() {
        // Get any pending console output
        var ch = cpm_get_char()
        while ch != 0 {
            // Convert to character and append
            let scalar = UnicodeScalar(ch)
            consoleOutput.append(Character(scalar))

            // Update the source code view to show console output
            // (In a real app, you'd have a separate console view)
            if consoleOutput.count > 5000 {
                // Trim to prevent memory issues
                consoleOutput = String(consoleOutput.suffix(4000))
            }
            textViewSourceCode.text = "CP/M Console:\n\n" + consoleOutput

            ch = cpm_get_char()
        }
    }
    
    @IBAction func tapStep(_ sender: Any) {
        labelRegisters.text = String(cString: codestep())
        highlightCurrentOpcode(UInt16(currentAddress()))
        updateBlinkenlights()
        updateConsoleOutput()
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        // Load the program code
        codeload(hexOutput, UInt32(orgAddress));
        labelRegisters.text = "OK: Code loaded"
        textViewSourceCode.text = assemblerOutput
        codereset()
        led_wait.isHidden = false
        updateBlinkenlights()
        viewAltair.transform = CGAffineTransform(scaleX: 2.1, y: 2.1)

        // For CP/M testing, send a test message
        if hexOutput.count > 0 {
            consoleOutput = "=== CP/M Console Output ===\n\n"
            textViewSourceCode.text = consoleOutput

            // Send some test characters to the CP/M input
            // These will be echoed back by the test program
            sendTestInput()
        }
    }

    func sendTestInput() {
        // Send "Hello\n" to CP/M console for testing
        let testString = "Hello, CP/M!\n"
        for char in testString.utf8 {
            cpm_put_char(char)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if running
        {
            running = false
            timer!.invalidate()

        }
    }
        
    func updateBlinkenlights()
    {
        let data = currentData()
        var address : Int32 = 0
        
        if running
        {
            address = currentAddressBus()
        }
        else
        {
            address = currentAddress()
        }
        
        led_a0.isHidden = (0 == (UInt(address) & 1))
        led_a1.isHidden = (0 == (UInt(address) & 2))
        led_a2.isHidden = (0 == (UInt(address) & 4))
        led_a3.isHidden = (0 == (UInt(address) & 8))
        led_a4.isHidden = (0 == (UInt(address) & 16))
        led_a5.isHidden = (0 == (UInt(address) & 32))
        led_a6.isHidden = (0 == (UInt(address) & 64))
        led_a7.isHidden = (0 == (UInt(address) & 128))
        
        led_a8.isHidden = (0 == (UInt(address) & 256))
        led_a9.isHidden = (0 == (UInt(address) & 512))
        led_a10.isHidden = (0 == (UInt(address) & 1024))
        led_a11.isHidden = (0 == (UInt(address) & 2048))
        led_a12.isHidden = (0 == (UInt(address) & 4096))
        led_a13.isHidden = (0 == (UInt(address) & 8192))
        led_a14.isHidden = (0 == (UInt(address) & 16384))
        led_a15.isHidden = (0 == (UInt(address) & 32768))
        
        led_d0.isHidden = (0 == (UInt(data) & 1))
        led_d1.isHidden = (0 == (UInt(data) & 2))
        led_d2.isHidden = (0 == (UInt(data) & 4))
        led_d3.isHidden = (0 == (UInt(data) & 8))
        led_d4.isHidden = (0 == (UInt(data) & 16))
        led_d5.isHidden = (0 == (UInt(data) & 32))
        led_d6.isHidden = (0 == (UInt(data) & 64))
        led_d7.isHidden = (0 == (UInt(data) & 128))
        
    }



}

// ============================================================================
// MARK: - CP/M Terminal View Controller
// ============================================================================

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Show keyboard automatically
        textView.becomeFirstResponder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Register for keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow),
                                               name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide),
                                               name: NSNotification.Name.UIKeyboardWillHide, object: nil)
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
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
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
        codeload(hexCode, UInt32(org))

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

        // Execute one instruction
        // The BDOS handler will retry the CALL if waiting for input
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
