/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 A view controller for displaying and editing documents.
 */

import UIKit
import os.log

/// - Tag: textDocumentViewController
class TextDocumentViewController: UIViewController, UITextViewDelegate, TextDocumentDelegate {
    
    private var browserTransition: DocumentBrowserTransitioningDelegate?
    public var transitionController: UIDocumentBrowserTransitionController? {
        didSet {
            if let controller = transitionController {
                // Set the transition animation.
                modalPresentationStyle = .custom
                browserTransition = DocumentBrowserTransitioningDelegate(withTransitionController: controller)
                transitioningDelegate = browserTransition
                
            } else {
                modalPresentationStyle = .none
                browserTransition = nil
                transitioningDelegate = nil
            }
        }
    }
    
    let CPU = Assemble()
    var currentOpcode = ""
    var nextOpcode = ""
    
    @IBOutlet weak var textViewAssembled: UITextView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var buttonDone: UIBarButtonItem!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var toolbarHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var buttonKTB: UIBarButtonItem!
    @IBOutlet weak var buttonEmulate: UIBarButtonItem!
    @IBOutlet weak var assembledCodeView: UIView!
    
    private var keyboardAppearObserver: Any?
    private var keyboardDisappearObserver: Any?
    
    public var document: TextDocument? {
        didSet {
            if let doc = document {
                doc.delegate = self
            }
        }
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupNotifications()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupNotifications()
    }
    
    deinit {
        let notificationCenter = NotificationCenter.default
        
        if let appearObserver = keyboardAppearObserver {
            notificationCenter.removeObserver(appearObserver)
        }
        
        if let disappearObserver = keyboardDisappearObserver {
            notificationCenter.removeObserver(disappearObserver)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        textView.delegate = self
        buttonDone.isEnabled = false
        buttonEmulate.isEnabled = false
        buttonKTB.isEnabled = true

        // Add a simple "CP/M Terminal" button
        addTerminalButton()
    }

    func addTerminalButton() {
        // Find the toolbar in the view hierarchy
        // The toolbar is in a stack view at the top
        for subview in view.subviews {
            if let stackView = subview as? UIStackView {
                for stackSubview in stackView.arrangedSubviews {
                    if let foundToolbar = stackSubview as? UIToolbar {
                        // Create a terminal button
                        let terminalButton = UIBarButtonItem(
                            title: "CP/M Terminal",
                            style: .plain,
                            target: self,
                            action: #selector(openCPMTerminal)
                        )

                        // Get existing toolbar items
                        guard var items = foundToolbar.items else { return }

                        // Insert terminal button before the "Done" button (second to last position)
                        let doneIndex = items.count - 1
                        items.insert(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), at: doneIndex)
                        items.insert(terminalButton, at: doneIndex)

                        // Update toolbar
                        foundToolbar.items = items
                        return
                    }
                }
            }
        }
    }

    @objc func openCPMTerminal() {
        // Load the Interactive Shell
        loadInteractiveCCP()

        // Assemble it
        tapAssemble(self)

        // Give assembly a moment to complete, then launch terminal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.tapTerminal(self as Any)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let doc = document else {
            fatalError("*** No Document Found! ***")
        }

        // Added this statement to make sure doc is editable after returning from
        // emulator view. Not sure what Apple's intent was.
        if (doc.documentState.contains(.closed))
        {
            doc.open(completionHandler: nil)
        }
        
        // Removed this assert, after adding preceding code.
        //  assert(!doc.documentState.contains(.closed),
        //       "*** Open the document before displaying it. ***")
        
        assert(!doc.documentState.contains(.inConflict),
               "*** Resolve conflicts before displaying the document. ***")
        
        textView.text = doc.text
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        guard let doc = document else {
            fatalError("*** No Document Found! ***")
        }
        
        doc.close { (success) in
            guard success else {
                fatalError( "*** Error saving document ***")
            }
            
            os_log("==> file Saved!", log: OSLog.default, type: .debug)
        }
    }
    
    // MARK: - Action Methods
    
    @IBAction func editingDone(_ sender: Any) {
        textView.resignFirstResponder()
        
        if let doc = document {
            doc.autosave(completionHandler: nil)
        }
    }
    
    @IBAction func returnToDocuments(_ sender: Any) {
        // Dismiss the editor view.
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - UITextViewDelegate
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        UIView.animate(withDuration: 0.25) {
            self.buttonDone.isEnabled = true
        }
        
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
        guard let doc = document else {
            fatalError("*** No Document Found! ***")
        }
        
        //   doc.text = textView.text // <- leaving this line in causes the cursor to skip after the user makes their first change. It's annoying, and seems to be unnecessary as 'didendediting' picks up the changes anyway.
        
        buttonKTB.isEnabled = false
        
        doc.updateChangeCount(.done)
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        
        
        UIView.animate(withDuration: 0.25) {
            self.buttonDone.isEnabled = false
        }
        
        guard let doc = document else {
            fatalError("*** No Document Found! ***")
        }
        
        doc.text = textView.text
        doc.updateChangeCount(.done)
    }
    
    // MARK: - UITextDocumentDelegate Methods
    
    func textDocumentEnableEditing(_ doc: TextDocument) {
        textView.isEditable = true
    }
    
    func textDocumentDisableEditing(_ doc: TextDocument) {
        textView.isEditable = false
    }
    
    func textDocumentUpdateContent(_ doc: TextDocument) {
        textView.text = doc.text
    }
    
    func textDocumentTransferBegan(_ doc: TextDocument) {
        progressBar.isHidden = false
        progressBar.observedProgress = doc.progress
    }
    
    func textDocumentTransferEnded(_ doc: TextDocument) {
        progressBar.isHidden = true
        self.view.layoutIfNeeded()
    }
    
    func textDocumentSaveFailed(_ doc: TextDocument) {
        let alert = UIAlertController(
            title: "Save Error",
            message: "An attempt to save the document failed",
            preferredStyle: .alert)
        
        let dismiss = UIAlertAction(title: "OK", style: .default) { (_) in
            // just dismiss the alert.
        }
        
        alert.addAction(dismiss)
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        
        let notificationCenter = NotificationCenter.default
        let mainQueue = OperationQueue.main
        
        keyboardAppearObserver = notificationCenter.addObserver(
            forName: NSNotification.Name.UIKeyboardWillShow,
            object: nil,
            queue: mainQueue) { [weak self](notification) in
                self?.keyboardWillShow(userInfo: notification.userInfo)
        }

        keyboardDisappearObserver = notificationCenter.addObserver(
            forName: NSNotification.Name.UIKeyboardWillHide,
            object: nil,
            queue: mainQueue) { [weak self](notification) in
                self?.keyboardWillHide(userInfo: notification.userInfo)
        }
    }
    
    private func keyboardWillShow(userInfo: [AnyHashable: Any]?) {
        guard let rawFrame =
            userInfo?[UIKeyboardFrameEndUserInfoKey]
                as? CGRect else {
                    fatalError("*** Unable to get the keyboard's final frame ***")
        }

        guard let animationDuration =
            userInfo?[UIKeyboardAnimationDurationUserInfoKey]
                as? Double else {
                    fatalError("*** Unable to get the animation duration ***")
        }

        guard let curveInt =
            userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? Int else {
                fatalError("*** Unable to get the animation curve ***")
        }
        
        guard let animationCurve =
            UIViewAnimationCurve(rawValue: curveInt) else {
                fatalError("*** Unable to parse the animation curve ***")
        }
        
        let height = self.view.convert(rawFrame, from: nil).size.height
        bottomConstraint.constant = height + 8.0
        
        UIViewPropertyAnimator(duration: animationDuration, curve: animationCurve) {
            self.view.layoutIfNeeded()
            }.startAnimation()
    }
    
    private func keyboardWillHide(userInfo: [AnyHashable: Any]?) {
        guard let animationDuration =
            userInfo?[UIKeyboardAnimationDurationUserInfoKey]
                as? Double else {
                    fatalError("*** Unable to get the animation duration ***")
        }

        guard let curveInt =
            userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? Int else {
                fatalError("*** Unable to get the animation curve ***")
        }
        
        guard let animationCurve =
            UIViewAnimationCurve(rawValue: curveInt) else {
                fatalError("*** Unable to parse the animation curve ***")
        }
        
        bottomConstraint.constant = 20.0
        
        UIViewPropertyAnimator(duration: animationDuration, curve: animationCurve) {
            self.view.layoutIfNeeded()
            }.startAnimation()
    }
    
    var sourceCode : String = ""
    var assemblerOutput : String = ""
    var octalOutput : String = ""
    var hexOutput : String = ""
    var orgAddress : UInt16 = 0


    @IBAction func tapAssemble(_ sender: Any) {

        // Get the source code, and Assemble it.

        sourceCode = textView.text

        let tokenized = CPU.Tokenize(code: sourceCode)
        let resultOutput = CPU.TwoPass(code: tokenized)
        assemblerOutput = resultOutput.1
        octalOutput = resultOutput.0
        hexOutput = resultOutput.2
        orgAddress = resultOutput.4

        textViewAssembled.text = "; Assembled code\n\n" + assemblerOutput + "\n\n; Octal" + octalOutput
        textViewAssembled.text.append("\n\n; Hex\n" + hexOutput)
        textViewAssembled.text.append("\n\n; ORG address: " + String(format: "%04Xh", orgAddress))

        // The user can activate the emulator only when code has assembled ok
        buttonEmulate.isEnabled = resultOutput.3
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Send the Hex codes and Source code to the Emulator view controller
        if segue.identifier == "emulator"
        {
            let controller = (segue.destination as! EmulatorViewController)
            controller.hexOutput = hexOutput
            controller.assemblerOutput = assemblerOutput
            controller.orgAddress = orgAddress
        }
    }

    @IBAction func tapTerminal(_ sender: Any) {
        // Launch the CP/M terminal with the assembled program

        guard buttonEmulate.isEnabled else {
            // Show alert if code hasn't been assembled
            let alert = UIAlertController(title: "Assemble First",
                                        message: "Please assemble your code before launching the terminal.",
                                        preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        // Create and present the terminal view controller
        let terminalVC = CPMTerminalViewController()
        let navController = UINavigationController(rootViewController: terminalVC)
        navController.modalPresentationStyle = .fullScreen

        present(navController, animated: true) {
            // Start the emulator with the assembled program
            terminalVC.startEmulator(withProgram: self.hexOutput, org: self.orgAddress)
        }
    }
    
    @IBAction func tapKillTheBit(_ sender: Any) {
        // Cycle through sample programs
        if textView.text.contains("Kill the Bit") {
            loadCPMEchoTest()
        } else if textView.text.contains("Echo") {
            loadCPMDiskTest()
        } else if textView.text.contains("Disk Test") {
            loadCPMFileTest()
        } else if textView.text.contains("File Operations") {
            loadCPMDirectoryTest()
        } else if textView.text.contains("Directory Operations") {
            loadCPMCCP()
        } else if textView.text.contains("CCP Demo") {
            loadKillTheBit()
        } else {
            loadKillTheBit()  // Default
        }
        tapAssemble(self)
    }

    func loadKillTheBit() {
        textView.text = ";  Kill the Bit game by Dean McDaniel, May 15, 1975\n;\n; Object: Kill the rotating bit. If you miss the lit bit, another        \n; bit turns on leaving two bits to destroy. Quickly        \n; toggle the switch, don't leave the switch in the up        \n; position. Before starting, make sure all the switches        \n; are in the down position.\n\norg 0h\n;initialize counter\nlxi     h,0        ;set up initial display bit        \nmvi     d,080h    ;higher value = faster        \nlxi     b,fe00h    ;display bit pattern on        \nbeg:\nldax    d        ;...upper 8 address lights        \nldax    d        \nldax    d        \nldax    d        \ndad     b        ;increment display counter        \njnc     beg        \nin      0ffh    ;input data from sense switches        \nxra     d        ;exclusive or with A        \nrrc                ;rotate display right one bit        \nmov     d,a        ;move data to display reg        \njmp     beg        ;repeat sequence        \nend"
    }

    func loadCPMEchoTest() {
        textView.text = "; CP/M Echo Test\n; Simple program to test CP/M BDOS calls\n; Reads characters and echoes them back\n\norg 100h     ; CP/M programs start at 0x0100\n\n; Set up BDOS call at 0x0005\ndb 0C3h      ; JMP instruction\ndb 05h       ; Low byte of address\ndb 00h       ; High byte (0x0005)\n\nloop:\n    mvi c, 01h   ; BDOS function 1: Console input\n    call 0005h   ; Call BDOS\n    mov e, a     ; Move char to E\n    mvi c, 02h   ; BDOS function 2: Console output  \n    call 0005h   ; Call BDOS\n    jmp loop     ; Repeat forever\n\nend"
    }

    func loadCPMDiskTest() {
        textView.text = "; CP/M Disk Test\n; Tests disk read/write operations\n; Success: A=FFh, Error: A=00h\n\norg 100h\n\n; Fill buffer with test pattern\n    lxi h, 0200h\n    mvi b, 080h\n    mvi a, 0AAh\nfill:\n    mov m, a\n    inx h\n    dcr b\n    jnz fill\n\n; Write via ports\n    mvi a, 00h\n    out 10h\n    out 11h\n    mvi a, 01h\n    out 12h\n    mvi a, 00h\n    out 13h\n    mvi a, 02h\n    out 14h\n    mvi a, 01h\n    out 15h\n\n; Clear buffer\n    lxi h, 0200h\n    mvi b, 080h\n    mvi a, 00h\nclr:\n    mov m, a\n    inx h\n    dcr b\n    jnz clr\n\n; Read back\n    mvi a, 00h\n    out 15h\n\n; Check first byte\n    lxi h, 0200h\n    mov a, m\n    xri 0AAh\n    jnz err\n\n; Success\n    mvi a, 0FFh\n    hlt\n\nerr:\n    mvi a, 00h\n    hlt\n\nend"
    }

    func loadCPMCCP() {
        textView.text = """
; CP/M Command Processor Demo
; Demonstrates: DIR, TYPE, ERA, REN
; Now with proper label names and multi-value DB!
; Success: A=FFh

org 100h

    ; Initialize stack pointer (critical!)
    lxi sp, 0FF00h

    ; Print banner
    lxi d, msg_banner
    mvi c, 09h
    call 0005h

    ; Create test files
    call create_files

    ; DIR command
    lxi d, msg_dir
    mvi c, 09h
    call 0005h
    call cmd_dir

    ; TYPE command
    lxi d, msg_type
    mvi c, 09h
    call 0005h
    call cmd_type

    ; REN command
    lxi d, msg_ren
    mvi c, 09h
    call 0005h
    call cmd_rename

    ; DIR again
    lxi d, msg_dir2
    mvi c, 09h
    call 0005h
    call cmd_dir

    ; ERA command
    lxi d, msg_era
    mvi c, 09h
    call 0005h
    call cmd_erase

    ; Final DIR
    lxi d, msg_dir3
    mvi c, 09h
    call 0005h
    call cmd_dir

    ; Done
    lxi d, msg_done
    mvi c, 09h
    call 0005h

    mvi a, 0FFh
    hlt

; Create test files
create_files:
    lxi d, fcb_test
    mvi c, 16h
    call 0005h

    lxi d, 0080h
    mvi c, 1Ah
    call 0005h

    lxi h, test_data
    lxi d, 0080h
    mvi b, 04h
copy_loop:
    mov a, m
    stax d
    inx h
    inx d
    dcr b
    jnz copy_loop

    lxi d, fcb_test
    mvi c, 15h
    call 0005h

    lxi d, fcb_test
    mvi c, 10h
    call 0005h

    lxi d, fcb_temp
    mvi c, 16h
    call 0005h
    lxi d, fcb_temp
    mvi c, 10h
    call 0005h

    ret

; DIR command
cmd_dir:
    lxi d, fcb_all
    mvi c, 11h
    call 0005h
    cpi 0FFh
    rz

dir_loop:
    call print_filename

    lxi d, fcb_all
    mvi c, 12h
    call 0005h
    cpi 0FFh
    jnz dir_loop
    ret

print_filename:
    lxi d, msg_space
    mvi c, 09h
    call 0005h

    ; Print filename (8 chars) - start at DMA+1 to skip user number
    lxi h, 0081h
    mvi b, 08h
print_name:
    mov a, m            ; Get character into A
    ani 7Fh             ; Mask off bit 7 (strip CP/M attribute bit)
    mov e, a            ; Move to E for BDOS
    mvi c, 02h          ; BDOS function 2: Console output
    call 0005h
    inx h
    dcr b
    jnz print_name

    ; Print dot separator
    mvi e, 2Eh          ; '.'
    mvi c, 02h
    call 0005h

    ; Print extension (3 chars)
    mvi b, 03h
print_ext:
    mov a, m            ; Get character into A
    ani 7Fh             ; Mask off bit 7 (strip CP/M attribute bit)
    mov e, a            ; Move to E for BDOS
    mvi c, 02h          ; BDOS function 2: Console output
    call 0005h
    inx h
    dcr b
    jnz print_ext

    ret

; TYPE command
cmd_type:
    lxi d, fcb_test
    mvi c, 0Fh
    call 0005h
    cpi 0FFh
    rz

type_loop:
    lxi d, fcb_test
    mvi c, 14h
    call 0005h
    ora a
    rnz

    lxi h, 0080h
    mvi b, 04h
char_loop:
    mov e, m
    mvi c, 02h
    call 0005h
    inx h
    dcr b
    jnz char_loop

    jmp type_loop

; REN command
cmd_rename:
    lxi d, fcb_rename
    mvi c, 17h
    call 0005h
    ret

; ERA command
cmd_erase:
    lxi d, fcb_temp
    mvi c, 13h
    call 0005h
    ret

; ===== Data =====
msg_banner:
    db 0Dh, 0Ah
    db 3Dh, 3Dh, 3Dh, 3Dh, 20h
    db 43h, 50h, 2Fh, 4Dh, 20h
    db 43h, 43h, 50h, 20h
    db 44h, 65h, 6Dh, 6Fh, 20h
    db 3Dh, 3Dh, 3Dh, 3Dh
    db 0Dh, 0Ah, 24h

msg_dir:
    db 0Dh, 0Ah
    db 41h, 3Eh, 44h, 49h, 52h
    db 0Dh, 0Ah, 24h

msg_type:
    db 0Dh, 0Ah
    db 41h, 3Eh
    db 54h, 59h, 50h, 45h, 20h
    db 54h, 45h, 53h, 54h, 2Eh
    db 54h, 58h, 54h
    db 0Dh, 0Ah, 24h

msg_ren:
    db 0Dh, 0Ah
    db 41h, 3Eh, 52h, 45h, 4Eh
    db 0Dh, 0Ah, 24h

msg_dir2:
    db 0Dh, 0Ah
    db 41h, 3Eh, 44h, 49h, 52h
    db 0Dh, 0Ah, 24h

msg_era:
    db 0Dh, 0Ah
    db 41h, 3Eh, 45h, 52h, 41h
    db 0Dh, 0Ah, 24h

msg_dir3:
    db 0Dh, 0Ah
    db 41h, 3Eh, 44h, 49h, 52h
    db 0Dh, 0Ah, 24h

msg_done:
    db 0Dh, 0Ah
    db 44h, 6Fh, 6Eh, 65h, 21h
    db 0Dh, 0Ah, 24h

msg_space:
    db 20h, 20h, 24h

test_data:
    db 48h, 69h, 21h, 0Ah

fcb_test:
    db 00h
    db 54h, 45h, 53h, 54h, 20h, 20h, 20h, 20h
    db 54h, 58h, 54h
    ds 21

fcb_temp:
    db 00h
    db 54h, 45h, 4Dh, 50h, 20h, 20h, 20h, 20h
    db 44h, 41h, 54h
    ds 21

fcb_all:
    db 00h
    db 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh
    db 3Fh, 3Fh, 3Fh
    ds 21

fcb_rename:
    ; Old name: TEST.TXT (bytes 0-11)
    db 00h                                          ; Byte 0: Drive
    db 54h, 45h, 53h, 54h, 20h, 20h, 20h, 20h      ; Bytes 1-8: "TEST    "
    db 54h, 58h, 54h                                ; Bytes 9-11: "TXT"
    ds 4                                            ; Bytes 12-15: Reserved (FIXED: was ds 5)
    ; New name: NEW.TXT (bytes 16-27)
    db 00h                                          ; Byte 16: Drive
    db 4Eh, 45h, 57h, 20h, 20h, 20h, 20h, 20h      ; Bytes 17-24: "NEW     "
    db 54h, 58h, 54h                                ; Bytes 25-27: "TXT"
    ds 4                                            ; Bytes 28-31: Reserved (FIXED: was ds 5)

end
"""
    }

    func loadCPMDirectoryTest() {
        textView.text = """
; CP/M Directory Operations Test
; Tests: Create files, List, Rename, Delete
; Success: A=FFh

org 100h

; === Create first file: FILE1.TXT ===
    lxi d, fcb1
    mvi c, 16h       ; BDOS function 22: Make File
    call 0005h
    cpi 0FFh
    jz error

; === Create second file: FILE2.DAT ===
    lxi d, fcb2
    mvi c, 16h       ; Make File
    call 0005h
    cpi 0FFh
    jz error

; === Search for all files (*.*)  ===
    lxi d, fcball
    mvi c, 11h       ; BDOS function 17: Search First
    call 0005h
    cpi 0FFh
    jz error         ; Should find at least one file

; === Rename FILE1.TXT to NEWFILE.TXT ===
    lxi d, fcb_rename
    mvi c, 17h       ; BDOS function 23: Rename
    call 0005h
    cpi 0FFh
    jz error

; === Delete FILE2.DAT ===
    lxi d, fcb2
    mvi c, 13h       ; BDOS function 19: Delete
    call 0005h
    cpi 0FFh
    jz error

; === Verify FILE2.DAT is gone ===
    lxi d, fcb2
    mvi c, 11h       ; Search First
    call 0005h
    cpi 00h
    jz error         ; Should NOT find it (A should be FFh)

; === Success! ===
    mvi a, 0FFh
    hlt

error:
    mvi a, 00h
    hlt

; === File Control Blocks ===
fcb1:
    db 00h           ; Drive
    db 46h           ; 'F'
    db 49h           ; 'I'
    db 4Ch           ; 'L'
    db 45h           ; 'E'
    db 31h           ; '1'
    db 20h           ; ' '
    db 20h           ; ' '
    db 20h           ; ' '
    db 54h           ; 'T'
    db 58h           ; 'X'
    db 54h           ; 'T'
    ds 21            ; Rest of FCB

fcb2:
    db 00h           ; Drive
    db 46h           ; 'F'
    db 49h           ; 'I'
    db 4Ch           ; 'L'
    db 45h           ; 'E'
    db 32h           ; '2'
    db 20h           ; ' '
    db 20h           ; ' '
    db 20h           ; ' '
    db 44h           ; 'D'
    db 41h           ; 'A'
    db 54h           ; 'T'
    ds 21

fcball:
    db 00h           ; Drive
    db 3Fh           ; '?'
    db 3Fh           ; '?'
    db 3Fh           ; '?'
    db 3Fh           ; '?'
    db 3Fh           ; '?'
    db 3Fh           ; '?'
    db 3Fh           ; '?'
    db 3Fh           ; '?'
    db 3Fh           ; '?'
    db 3Fh           ; '?'
    db 3Fh           ; '?'
    ds 21

fcb_rename:
    ; Old name: TEST.TXT (bytes 0-11)
    db 00h           ; Byte 0: Drive
    db 54h           ; 'T' - Byte 1
    db 45h           ; 'E' - Byte 2
    db 53h           ; 'S' - Byte 3
    db 54h           ; 'T' - Byte 4
    db 20h           ; ' ' - Byte 5
    db 20h           ; ' ' - Byte 6
    db 20h           ; ' ' - Byte 7
    db 20h           ; ' ' - Byte 8
    db 54h           ; 'T' - Byte 9
    db 58h           ; 'X' - Byte 10
    db 54h           ; 'T' - Byte 11
    ds 4             ; Bytes 12-15: Reserved (FIXED: was ds 5)
    ; New name: NEW.TXT (bytes 16-27)
    db 00h           ; Byte 16: Drive
    db 4Eh           ; 'N' - Byte 17
    db 45h           ; 'E' - Byte 18
    db 57h           ; 'W' - Byte 19
    db 20h           ; ' ' - Byte 20
    db 20h           ; ' ' - Byte 21
    db 20h           ; ' ' - Byte 22
    db 20h           ; ' ' - Byte 23
    db 20h           ; ' ' - Byte 24
    db 54h           ; 'T' - Byte 25
    db 58h           ; 'X' - Byte 26
    db 54h           ; 'T' - Byte 27
    ds 4             ; Bytes 28-31: Reserved

end
"""
    }

    func loadCPMFileTest() {
        textView.text = """
; CP/M File Operations Test
; Tests: Create, Write, Close, Open, Read
; Success: A=FFh, Error: A=00h

org 100h

; === Step 1: Create file TEST.TXT ===
    lxi d, fcb       ; DE = FCB address
    mvi c, 16h       ; BDOS function 22: Make File
    call 0005h       ; Call BDOS
    cpi 0FFh
    jz error         ; Jump if error

; === Step 2: Write data to file ===
    lxi d, fcb       ; DE = FCB
    lxi h, data      ; HL = data source
    lxi b, 0080h     ; BC = DMA address
    mvi a, 04h       ; 4 bytes to write
    sta count

write_loop:
    ; Copy one byte to DMA buffer
    mov a, m
    stax b
    inx h
    inx b
    lda count
    dcr a
    sta count
    jnz write_loop

    ; Set DMA address to 0x0080
    lxi d, 0080h
    mvi c, 1Ah       ; BDOS function 26: Set DMA
    call 0005h

    ; Write record
    lxi d, fcb
    mvi c, 15h       ; BDOS function 21: Write Sequential
    call 0005h
    ora a
    jnz error

; === Step 3: Close file ===
    lxi d, fcb
    mvi c, 10h       ; BDOS function 16: Close File
    call 0005h
    cpi 0FFh
    jz error

; === Step 4: Open file ===
    lxi d, fcb
    mvi c, 0Fh       ; BDOS function 15: Open File
    call 0005h
    cpi 0FFh
    jz error

; === Step 5: Read file ===
    lxi d, 0080h
    mvi c, 1Ah       ; Set DMA
    call 0005h

    lxi d, fcb
    mvi c, 14h       ; BDOS function 20: Read Sequential
    call 0005h
    ora a
    jnz error

; === Step 6: Verify data ===
    lxi h, 0080h     ; DMA buffer
    lxi d, data      ; Expected data
    mvi b, 04h       ; 4 bytes

verify:
    ldax d
    cmp m
    jnz error        ; Mismatch!
    inx h
    inx d
    dcr b
    jnz verify

; === Success ===
    mvi a, 0FFh
    hlt

error:
    mvi a, 00h
    hlt

; === Data ===
fcb:
    db 00h           ; Drive (0 = default)
    db 54h           ; 'T'
    db 45h           ; 'E'
    db 53h           ; 'S'
    db 54h           ; 'T'
    db 20h           ; ' '
    db 20h           ; ' '
    db 20h           ; ' '
    db 20h           ; ' '
    db 54h           ; 'T'
    db 58h           ; 'X'
    db 54h           ; 'T'
    db 00h           ; Extent
    db 00h           ; Reserved
    db 00h           ; Reserved
    db 00h           ; Record count
    ds 16            ; Allocation (16 bytes)
    db 00h           ; Current record

data:
    db 41h           ; 'A'
    db 42h           ; 'B'
    db 43h           ; 'C'
    db 44h           ; 'D'

count:
    db 00h

end
"""
    }

    func loadInteractiveCCP() {
        textView.text = """
; CP/M Interactive Shell (CCP)
; A simple Console Command Processor with:
; - DIR: List directory
; - TYPE filename: Display file contents
; - ERA filename: Delete file
; - REN new old: Rename file
; - EXIT: Halt system

org 100h

; ===== Main Loop =====
start:
    ; Print prompt
    lxi d, prompt
    mvi c, 09h
    call 0005h

    ; Read command line
    lxi d, cmd_buffer
    mvi c, 0Ah          ; BDOS function 10: Read buffer
    call 0005h

    ; Get length and check if empty
    lda cmd_buffer_len
    ora a
    jz start            ; Empty line, show prompt again

    ; Convert to uppercase and parse
    call parse_command
    jmp start           ; Loop forever

; ===== Parse Command =====
parse_command:
    ; Point to first character of command
    lxi h, cmd_buffer_data

    ; Check for DIR
    mov a, m
    cpi 44h             ; 'D'
    jnz check_type
    inx h
    mov a, m
    cpi 49h             ; 'I'
    jnz check_type
    inx h
    mov a, m
    cpi 52h             ; 'R'
    jnz check_type
    jmp cmd_dir

check_type:
    ; Check for TYPE
    lxi h, cmd_buffer_data
    mov a, m
    cpi 54h             ; 'T'
    jnz check_era
    inx h
    mov a, m
    cpi 59h             ; 'Y'
    jnz check_era
    inx h
    mov a, m
    cpi 50h             ; 'P'
    jnz check_era
    inx h
    mov a, m
    cpi 45h             ; 'E'
    jnz check_era
    ; Parse filename for TYPE command
    lxi h, cmd_buffer_data_5  ; Skip "TYPE "
    lxi d, fcb_temp
    call parse_filename
    jmp cmd_type

check_era:
    ; Check for ERA
    lxi h, cmd_buffer_data
    mov a, m
    cpi 45h             ; 'E'
    jnz check_ren
    inx h
    mov a, m
    cpi 52h             ; 'R'
    jnz check_ren
    inx h
    mov a, m
    cpi 41h             ; 'A'
    jnz check_ren
    ; Parse filename for ERA command
    lxi h, cmd_buffer_data_4  ; Skip "ERA "
    lxi d, fcb_temp
    call parse_filename
    jmp cmd_era

check_ren:
    ; Check for REN
    lxi h, cmd_buffer_data
    mov a, m
    cpi 52h             ; 'R'
    jnz check_exit
    inx h
    mov a, m
    cpi 45h             ; 'E'
    jnz check_exit
    inx h
    mov a, m
    cpi 4Eh             ; 'N'
    jnz check_exit
    jmp cmd_ren_setup

check_exit:
    ; Check for EXIT
    lxi h, cmd_buffer_data
    mov a, m
    cpi 45h             ; 'E'
    jnz unknown_cmd
    inx h
    mov a, m
    cpi 58h             ; 'X'
    jnz unknown_cmd
    inx h
    mov a, m
    cpi 49h             ; 'I'
    jnz unknown_cmd
    inx h
    mov a, m
    cpi 54h             ; 'T'
    jnz unknown_cmd
    ; Exit - halt system
    lxi d, msg_goodbye
    mvi c, 09h
    call 0005h
    hlt

unknown_cmd:
    lxi d, msg_unknown
    mvi c, 09h
    call 0005h
    ret

; ===== Parse Filename =====
; HL = source, DE = FCB dest
parse_filename:
    push b
    push h
    push d

    ; Initialize FCB with spaces
    xchg
    mvi m, 00h          ; Drive
    inx h
    mvi b, 11
fill_spaces:
    mvi m, 20h          ; Space character
    inx h
    dcr b
    jnz fill_spaces

    ; Copy filename (up to 8 chars or '.')
    xchg
    pop d
    push d
    inx d               ; Skip drive byte
    mvi b, 8
copy_name:
    mov a, m
    cpi 20h             ; Space
    jz parse_ext
    cpi 2Eh             ; Period '.'
    jz parse_ext
    cpi 00h             ; Null terminator
    jz parse_done
    cpi 0Dh             ; CR
    jz parse_done
    stax d
    inx h
    inx d
    dcr b
    jnz copy_name

parse_ext:
    ; Skip to extension
skip_dot:
    mov a, m
    cpi 2Eh             ; Period '.'
    jz found_dot
    cpi 20h             ; Space
    jz parse_done
    cpi 00h             ; Null terminator
    jz parse_done
    cpi 0Dh             ; CR
    jz parse_done
    inx h
    jmp skip_dot

found_dot:
    inx h
    pop d
    push d
    lxi b, 9
    xchg
    dad b               ; Point to extension in FCB
    xchg
    mvi b, 3
copy_ext:
    mov a, m
    cpi 20h             ; Space
    jz parse_done
    cpi 00h             ; Null terminator
    jz parse_done
    cpi 0Dh             ; CR
    jz parse_done
    stax d
    inx h
    inx d
    dcr b
    jnz copy_ext

parse_done:
    pop d
    pop h
    pop b
    ret

; ===== DIR Command =====
cmd_dir:
    lxi d, msg_newline
    mvi c, 09h
    call 0005h

    ; Search for first file (*.*)
    lxi d, fcb_all
    mvi c, 11h          ; BDOS function 17: Search first
    call 0005h
    cpi 0FFh
    rz                  ; No files found

dir_loop:
    call print_dir_entry

    ; Search for next
    lxi d, fcb_all
    mvi c, 12h          ; BDOS function 18: Search next
    call 0005h
    cpi 0FFh
    jnz dir_loop

    lxi d, msg_newline
    mvi c, 09h
    call 0005h
    ret

print_dir_entry:
    ; Print spacing
    lxi d, msg_space
    mvi c, 09h
    call 0005h

    ; Print filename (8 chars) from DMA+1
    lxi h, 0081h
    mvi b, 08h
print_name:
    mov a, m
    ani 7Fh             ; Mask attribute bit
    mov e, a
    mvi c, 02h
    call 0005h
    inx h
    dcr b
    jnz print_name

    ; Print dot
    mvi e, 2Eh          ; Period '.'
    mvi c, 02h
    call 0005h

    ; Print extension (3 chars)
    mvi b, 03h
print_ext:
    mov a, m
    ani 7Fh
    mov e, a
    mvi c, 02h
    call 0005h
    inx h
    dcr b
    jnz print_ext

    ret

; ===== TYPE Command =====
cmd_type:
    ; Open file
    lxi d, fcb_temp
    mvi c, 0Fh          ; BDOS function 15: Open file
    call 0005h
    cpi 0FFh
    jz file_not_found

    lxi d, msg_newline
    mvi c, 09h
    call 0005h

type_loop:
    ; Read sequential
    lxi d, fcb_temp
    mvi c, 14h          ; BDOS function 20: Read sequential
    call 0005h
    ora a
    jnz type_done       ; End of file

    ; Display buffer contents
    lxi h, 0080h
    mvi b, 128
display_char:
    mov e, m
    mov a, e
    cpi 1Ah             ; CP/M EOF marker (^Z)
    jz type_done
    mvi c, 02h
    call 0005h
    inx h
    dcr b
    jnz display_char
    jmp type_loop

type_done:
    lxi d, msg_newline
    mvi c, 09h
    call 0005h
    ret

file_not_found:
    lxi d, msg_not_found
    mvi c, 09h
    call 0005h
    ret

; ===== ERA Command =====
cmd_era:
    lxi d, fcb_temp
    mvi c, 13h          ; BDOS function 19: Delete file
    call 0005h
    cpi 0FFh
    jz file_not_found

    lxi d, msg_deleted
    mvi c, 09h
    call 0005h
    ret

; ===== REN Command =====
cmd_ren_setup:
    ; TODO: Parse two filenames from command line
    lxi d, msg_unknown
    mvi c, 09h
    call 0005h
    ret

; ===== Data =====
prompt:
    db 0Dh, 0Ah, 41h, 3Eh, 24h    ; CR LF "A>" $

msg_newline:
    db 0Dh, 0Ah, 24h               ; CR LF $

msg_space:
    db 20h, 20h, 24h               ; "  " $

msg_unknown:
    db 0Dh, 0Ah, 55h, 6Eh, 6Bh, 6Eh, 6Fh, 77h, 6Eh, 20h
    db 63h, 6Fh, 6Dh, 6Dh, 61h, 6Eh, 64h
    db 0Dh, 0Ah, 24h               ; "Unknown command"

msg_not_found:
    db 0Dh, 0Ah, 46h, 69h, 6Ch, 65h, 20h
    db 6Eh, 6Fh, 74h, 20h, 66h, 6Fh, 75h, 6Eh, 64h
    db 0Dh, 0Ah, 24h               ; "File not found"

msg_deleted:
    db 0Dh, 0Ah, 46h, 69h, 6Ch, 65h, 20h
    db 64h, 65h, 6Ch, 65h, 74h, 65h, 64h
    db 0Dh, 0Ah, 24h               ; "File deleted"

msg_goodbye:
    db 0Dh, 0Ah, 47h, 6Fh, 6Fh, 64h, 62h, 79h, 65h, 21h
    db 0Dh, 0Ah, 24h               ; "Goodbye!"

; Command buffer: max 40 chars
cmd_buffer:
    db 40               ; Byte 0: Max length
cmd_buffer_len:
    db 0                ; Byte 1: Actual length (filled by BDOS)
cmd_buffer_data:
    db 0, 0, 0, 0       ; Bytes 2-5
cmd_buffer_data_4:
    db 0                ; Byte 6 (for "ERA " - skip 4 chars)
cmd_buffer_data_5:
    db 0                ; Byte 7 (for "TYPE " - skip 5 chars)
    ds 34               ; Bytes 8-41 (rest of buffer)

; FCBs
fcb_all:
    db 00h
    db 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh, 3Fh
    db 3Fh, 3Fh, 3Fh
    ds 21

fcb_temp:
    db 00h
    db 20h, 20h, 20h, 20h, 20h, 20h, 20h, 20h
    db 20h, 20h, 20h
    ds 21

end
"""
    }

}
