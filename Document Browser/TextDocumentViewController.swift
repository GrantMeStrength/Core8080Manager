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
    
    @IBOutlet weak var textViewAssembled: UITextView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var toolbarHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var regLabel: UILabel!
    @IBOutlet weak var viewBlinklenights: UIView!
    
    // Blinkenlights
    
    @IBOutlet weak var led_a0: UIImageView!
    @IBOutlet weak var led_a1: UIImageView!
    @IBOutlet weak var led_a2: UIImageView!
    @IBOutlet weak var led_a3: UIImageView!
    @IBOutlet weak var led_a4: UIImageView!
    @IBOutlet weak var led_a5: UIImageView!
    @IBOutlet weak var led_a6: UIImageView!
    @IBOutlet weak var led_a7: UIImageView!
    
    @IBOutlet weak var led_d0: UIImageView!
    @IBOutlet weak var led_d1: UIImageView!
    @IBOutlet weak var led_d2: UIImageView!
    @IBOutlet weak var led_d3: UIImageView!
    @IBOutlet weak var led_d4: UIImageView!
    @IBOutlet weak var led_d5: UIImageView!
    @IBOutlet weak var led_d6: UIImageView!
    @IBOutlet weak var led_d7: UIImageView!
    
    
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
        doneButton.isEnabled = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let doc = document else {
            fatalError("*** No Document Found! ***")
        }
        
        assert(!doc.documentState.contains(.closed),
               "*** Open the document before displaying it. ***")
        
        assert(!doc.documentState.contains(.inConflict),
               "*** Resolve conflicts before displaying the document. ***")
        
        textView.text = doc.text
        
        viewBlinklenights.isHidden = true
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
            self.doneButton.isEnabled = true
        }

    }
    
    func textViewDidChange(_ textView: UITextView) {
        
        guard let doc = document else {
            fatalError("*** No Document Found! ***")
        }
        
        doc.text = textView.text
        doc.updateChangeCount(.done)
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        
        UIView.animate(withDuration: 0.25) {
            self.doneButton.isEnabled = false
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
            forName: .UIKeyboardWillShow,
            object: nil,
            queue: mainQueue) { [weak self](notification) in
                self?.keyboardWillShow(userInfo: notification.userInfo)
        }
        
        keyboardDisappearObserver = notificationCenter.addObserver(
            forName: .UIKeyboardWillHide,
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
    var octalOutput : String = "(Assemble some code to see the octal codes here.)"
    var hexOutput : String = ""
    
    
    @IBAction func tapAssemble(_ sender: Any) {
        
        // Get the source code, and Assemble it.
        // Now need to worry where to put it..
        
        sourceCode = textView.text
        
        let CPU = Assemble()
        let tokenized = CPU.Tokenize(code: sourceCode)
        let resultOutput = CPU.TwoPass(code: tokenized)
        assemblerOutput = resultOutput.1
        octalOutput = resultOutput.0
        hexOutput = resultOutput.2
        
        textViewAssembled.text = "Assembled code\n\n" + assemblerOutput + "\n\nOctal" + octalOutput
        textViewAssembled.text.append("\n\nHex\n" + hexOutput)

    }
    
    
    @IBAction func tapEmulator(_ sender: Any) {
        viewBlinklenights.isHidden = !viewBlinklenights.isHidden
        self.view.layoutIfNeeded()
    }
    
    @IBAction func load(_ sender: Any) {
        codeload(hexOutput);
        regLabel.text = "OK: Code loaded"
        updateBlinkenlights()
    }
    
    
    @IBAction func step(_ sender: Any) {
    
       regLabel.text = String(cString: codestep())
        updateBlinkenlights()
       
   }
    
    @IBAction func reset(_ sender: Any) {
      regLabel.text = String(cString: codereset())
        updateBlinkenlights()
    }
    
    @IBAction func tapRun(_ sender: Any) {
        
      coderun()
        regLabel.text = "Running"

    }
    
    
    
    func updateBlinkenlights()
    {
        let data = currentData()
        let address = currentAddress()
        
        led_a0.isHidden = (0 == (UInt(address) & 1))
        led_a1.isHidden = (0 == (UInt(address) & 2))
        led_a2.isHidden = (0 == (UInt(address) & 4))
        led_a3.isHidden = (0 == (UInt(address) & 8))
        led_a4.isHidden = (0 == (UInt(address) & 16))
        led_a5.isHidden = (0 == (UInt(address) & 32))
        led_a6.isHidden = (0 == (UInt(address) & 64))
        led_a7.isHidden = (0 == (UInt(address) & 128))
        
        led_d0.isHidden = (0 == (UInt(data) & 1))
        led_d1.isHidden = (0 == (UInt(data) & 2))
        led_d2.isHidden = (0 == (UInt(data) & 4))
        led_d3.isHidden = (0 == (UInt(data) & 8))
        led_d4.isHidden = (0 == (UInt(data) & 16))
        led_d5.isHidden = (0 == (UInt(data) & 32))
        led_d6.isHidden = (0 == (UInt(data) & 64))
        led_d7.isHidden = (0 == (UInt(data) & 128))
        
    }
    
    public class CustomTraitCollectionViewController: UIViewController {
        override public var traitCollection: UITraitCollection {
            
            if UIDevice.current.userInterfaceIdiom == .pad &&
                UIDevice.current.orientation.isPortrait {
                return UITraitCollection(traitsFrom:[UITraitCollection(horizontalSizeClass: .compact), UITraitCollection(verticalSizeClass: .regular)])
            }
            return super.traitCollection
        }
    }
    
}
