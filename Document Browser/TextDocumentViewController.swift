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
    
    
    @IBAction func tapAssemble(_ sender: Any) {
        
        // Get the source code, and Assemble it.
        
        sourceCode = textView.text
        
        let tokenized = CPU.Tokenize(code: sourceCode)
        let resultOutput = CPU.TwoPass(code: tokenized)
        assemblerOutput = resultOutput.1
        octalOutput = resultOutput.0
        hexOutput = resultOutput.2
        
        textViewAssembled.text = "; Assembled code\n\n" + assemblerOutput + "\n\n; Octal" + octalOutput
        textViewAssembled.text.append("\n\n; Hex\n" + hexOutput)
        
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
        }
    }
    
    @IBAction func tapKillTheBit(_ sender: Any) {
        // Cycle through sample programs
        if textView.text.contains("Disk") {
            loadKillTheBit()
        } else if textView.text.contains("Echo") {
            loadCPMDiskTest()
        } else {
            loadCPMEchoTest()
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

}
