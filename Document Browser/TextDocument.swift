/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A document that manages UTF8 text files.
*/

import UIKit
import os.log

enum TextDocumentError: Error {
    case unableToParseText
    case unableToEncodeText
}

protocol TextDocumentDelegate: class {
    func textDocumentEnableEditing(_ doc: TextDocument)
    func textDocumentDisableEditing(_ doc: TextDocument)
    func textDocumentUpdateContent(_ doc: TextDocument)
    func textDocumentTransferBegan(_ doc: TextDocument)
    func textDocumentTransferEnded(_ doc: TextDocument)
    func textDocumentSaveFailed(_ doc: TextDocument)
}

/// - Tag: TextDocument
class TextDocument: UIDocument {
    
    public var text = "" {
        didSet {
            // Notify the delegate when the text changes.
            if let currentDelegate = delegate {
                currentDelegate.textDocumentUpdateContent(self)
            }
        }
    }
        
    public weak var delegate: TextDocumentDelegate?
    public var loadProgress = Progress(totalUnitCount: 10)
    
    private var docStateObserver : Any?
    private var transfering: Bool = false
    
    override init(fileURL url: URL) {
        
        docStateObserver = nil
        super.init(fileURL: url)
        
        let notificationCenter = NotificationCenter.default
        let mainQueue = OperationQueue.main
        
        docStateObserver = notificationCenter.addObserver(
            forName: .UIDocumentStateChanged,
            object: self,
            queue: mainQueue) { [weak self](_) in
                
                guard let doc = self else {
                    return
                }
                
                doc.updateDocumentState()
        }
    }
    
    init() {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("MyTextDoc.txt")
        
        super.init(fileURL: url)
    }
    
    deinit {
        if let docObserver = docStateObserver {
            NotificationCenter.default.removeObserver(docObserver)
        }
    }
    
    override func contents(forType typeName: String) throws -> Any {
        
        guard let data = text.data(using: .utf8) else {
            throw TextDocumentError.unableToEncodeText
        }
        
        os_log("==> Text Data Saved", log: OSLog.default, type: .debug)
        
        return data as Any
    }
    
//    // Uncomment to simulate slow, incremental loading.
//    override func read(from url: URL) throws {
//
//        let group = DispatchGroup()
//        let backgroundQueue = DispatchQueue(label: "Background Queue", qos: .background)
//        let theProgress = loadProgress
//
//        // Simulate a slow load.
//        for i in 1..<loadProgress.totalUnitCount {
//            group.enter()
//            backgroundQueue.async {
//                Thread.sleep(forTimeInterval: 0.25)
//                theProgress.completedUnitCount = i
//                group.leave()
//            }
//        }
//
//        // Wait until all the parts have loaded, then call super.
//        group.wait()
//        try super.read(from: url)
//
//        // Mark the progress as complete
//        loadProgress.completedUnitCount = loadProgress.totalUnitCount

//    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        
        guard let data = contents as? Data else {
            // This would be a developer error.
            fatalError("*** \(contents) is not an instance of NSData.***")
        }
        
        guard let newText = String(data: data, encoding: .utf8) else {
            throw TextDocumentError.unableToParseText
        }
        
        // Mark the progress as complete
        loadProgress.completedUnitCount = loadProgress.totalUnitCount
        
        os_log("==> Text Data Loaded", log: OSLog.default, type: .debug)
        text = newText
    }
    
    // MARK: - Private Methods
    
    private func updateDocumentState() {
        
        if documentState == .normal {
            os_log("=> Document entered normal state", log: OSLog.default, type: .debug)
            if let currentDelegate = delegate {
                currentDelegate.textDocumentEnableEditing(self)
            }
        }
        
        if documentState.contains(.closed) {
            os_log("=> Document has closed", log: OSLog.default, type: .debug)
            if let currentDelegate = delegate {
                currentDelegate.textDocumentDisableEditing(self)
            }
        }
        
        if documentState.contains(.editingDisabled) {
            os_log("=> Document's editing is disabled", log: OSLog.default, type: .debug)
            if let currentDelegate = delegate {
                currentDelegate.textDocumentDisableEditing(self)
            }
        }
        
        if documentState.contains(.inConflict) {
            os_log("=> A docuent conflict was detected", log: OSLog.default, type: .debug)
            resolveDocumentConflict()
        }
        
        if documentState.contains(.savingError) {
            if let currentDelegate = delegate {
                currentDelegate.textDocumentSaveFailed(self)
            }
        }
        
        handleDocStateForTransfers()
    }
    
    private func handleDocStateForTransfers() {
        if transfering {
            // If we're in the middle of a transfer, check to see if the transfer has ended.
            if !documentState.contains(.progressAvailable) {
                transfering = false
                if let currentDelegate = delegate {
                    currentDelegate.textDocumentTransferEnded(self)
                }
            }
        } else {
            // If we're not in the middle of a transfer, check to see if a transfer has started.
            if documentState.contains(.progressAvailable) {
                os_log("=> A transfer is in progress", log: OSLog.default, type: .debug)
                
                if let currentDelegate = delegate {
                    currentDelegate.textDocumentTransferBegan(self)
                    transfering = true
                }
            }
        }
    }
    
    private func resolveDocumentConflict() {
        
        // To accept the current version, remove the other versions,
        // and resolve all the unresolved versions.
        
        do {
            try NSFileVersion.removeOtherVersionsOfItem(at: fileURL)
            
            if let conflictingVersions = NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL) {
                for version in conflictingVersions {
                    version.isResolved = true
                }
            }
        } catch let error {
            os_log("*** Error: %@ ***", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
}
