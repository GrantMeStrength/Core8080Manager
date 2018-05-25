# Building a Document Browser-Based App

Use a document browser to provide access to the user's text files.

## Overview

The Document Browser sample code uses a `UIDocumentBrowserViewController` as the app's root view controller. The browser defines the structure of the app, and the app displays the browser view when it launches. Users can then use the browser to:

* Browse all the text files on the user's device, in their iCloud drive, or in any supported third-party file providers.

* Create new text files.

* Open text files.

When the user opens a file, the app transitions to an editor view. There, the user can edit and save the text file. When they are done editing, the app returns to the browser, letting the user open or create another file. 

This sample code project demonstrates all the required steps to set up the document browser, to work with the user's files, and to enable system animations. The following sections describe these steps in more detail.

## Setting Up the Document Browser

The Document Browser app performs the following setup and configuration steps: 

1. Assigns a `UIDocumentBrowserViewController` subclass as the window's `rootViewController`.
2. Specifies the supported document types.
3. Customizes the document browser's behavior.

Document browser-based apps must assign a [`UIDocumentBrowserViewController`](uidocumentbrowserviewcontroller) instance as the app's [`rootViewController`](https://developer.apple.com/documentation/uikit/uiwindow/1621581-rootviewcontroller), ensuring that the browser remains in memory throughout the app's lifetime.

The sample code defines a `UIDocumentBrowserViewController` subclass named  [`DocumentBrowserViewController`](x-source-tag://DocumentBrowserViewController). It then marks the subclass as the app's initial view controller in the `Main.storyboard` storyboard, and  displays the browser view when launched.

All document browser-based apps must also declare the document types that they can open. The sample code app declares support for text files in the project editor's Info pane. For more information on setting the document type, see [Setting Up a Document Browser App](https://developer.apple.com/documentation/uikit/view_controllers/adding_a_document_browser_to_your_app/setting_up_a_document_browser_app).

Finally, the sample code configures the document browser in the `DocumentBrowserViewController` class's [`viewDidLoad()`](x-source-tag://presentDocuments) method. Specifically, it enables document creation, and disables multiple document selection. This lets users create new documents from the browser, while also preventing them from opening more than one document at a time.

``` swift
allowsDocumentCreation = true
allowsPickingMultipleItems = false
```

For more information on configuring a document browser, see [Customizing the Browser](https://developer.apple.com/documentation/uikit/view_controllers/adding_a_document_browser_to_your_app/customizing_the_browser)

## Creating New Documents

When the user creates a new document, the system calls the document browser delegate's [`documentBrowser(_:didRequestDocumentCreationWithHandler:)`](https://developer.apple.com/documentation/uikit/uidocumentbrowserviewcontrollerdelegate/2874199-documentbrowser) method.

``` swift
// Create a new document.
func documentBrowser(_ controller: UIDocumentBrowserViewController,
                     didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
    
    os_log("==> Creating A New Document.", log: OSLog.default, type: .debug)
    
    let doc = TextDocument()
    let url = doc.fileURL
    
    // Create a new document in a temporary location.
    doc.save(to: url, for: .forCreating) { (saveSuccess) in
        
        // Make sure the document saved successfully.
        guard saveSuccess else {
            os_log("*** Unable to create a new document. ***", log: OSLog.default, type: .error)
            
            // Cancel document creation.
            importHandler(nil, .none)
            return
        }
        
        // Close the document.
        doc.close(completionHandler: { (closeSuccess) in
            
            // Make sure the document closed successfully.
            guard closeSuccess else {
                os_log("*** Unable to create a new document. ***", log: OSLog.default, type: .error)
                
                // Cancel document creation.
                importHandler(nil, .none)
                return
            }
            
            // Pass the document's temporary URL to the import handler.
            importHandler(url, .move)
        })
    }
}
```

In this method, the app creates, saves, and then closes a new text document. If successful, the app passes the URL to the method's import handler, requesting that the system move the document to its final location. Otherwise, it passes `nil` to the import handler, canceling document creation.

## Opening and Importing Documents.

Users can open documents in multiple ways. The sample code handles the following situations:

* If the app imports a document (including successfully creating a new document), the system calls the [`documentBrowser(_:didImportDocumentAt:toDestinationURL:)`](https://developer.apple.com/documentation/uikit/uidocumentbrowserviewcontrollerdelegate/2874196-documentbrowser) method. 
* If the user selects a document from the browser, the system calls the [`documentBrowser(_:didPickDocumentURLs:)`](https://developer.apple.com/documentation/uikit/uidocumentbrowserviewcontrollerdelegate/2874187-documentbrowser) method.
* If the user shares a document with the app, or drags a document into the app, the system calls the app delegate's  [`application(_:open:options:)`](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623112-application) method.

In the first two cases, the app calls the custom [`presentDocuments(at:)`](x-source-tag://presentDocuments) method. In the third case, the app calls the browser's [`revealDocument(at:importIfNeeded:completion:`)](https://developer.apple.com/documentation/uikit/uidocumentbrowserviewcontroller/2915849-revealdocument) method to import the document (if needed). It then calls the `presentDocuments(at:)` method.

``` swift
// MARK: Document Presentation
/// - Tag: presentDocuments
func presentDocument(at documentURL: URL) {
    
    let storyBoard = UIStoryboard(name: "Main", bundle: nil)
    
    let tempController = storyBoard.instantiateViewController(withIdentifier: "TextDocumentViewController")
    
    guard let documentViewController = tempController as? TextDocumentViewController else {
        fatalError("*** Unable to cast \(tempController) into a TextDocumentViewController ***")
    }
    
    // Load the document view.
    documentViewController.loadViewIfNeeded()
    
    let doc = TextDocument(fileURL: documentURL)
    
    // Get the transition controller.
    let transitionController = self.transitionController(forDocumentURL: documentURL)
    
    // Set up the transition animation.
    transitionController.targetView = documentViewController.textView
    documentViewController.transitionController = transitionController
    
    // Set up the loading animation.
    transitionController.loadingProgress = doc.loadProgress
    
    // Set and open the document.
    documentViewController.document = doc

    doc.open { [weak self](success) in
        
        // Remove the loading animation.
        transitionController.loadingProgress = nil
        
        guard success else {
            fatalError("*** Unable to open the text file ***")
        }
        
        os_log("==> Document Opened!", log: OSLog.default, type: .debug)
        self?.present(documentViewController, animated: true, completion: nil)
    }
}
```

The `presentDocuments(at:)` method instantiates a [`TextDocumentViewController`](x-source-tag://textDocumentViewController), sets up the document's animation, opens the document, and then presents the view controller by calling the browser's [present(_:animated:completion:)](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621380-present) method.

## Enabling Animations

The document browser provides two built-in animations: one for loading a file, another for transitioning to and from the document view.

To enable either of the system-provided document browser animations, first you need to request a transition controller for the document by calling the [transitionController(forDocumentURL:)](https://developer.apple.com/documentation/uikit/uidocumentbrowserviewcontroller/2874177-transitioncontroller) method.

```swift
// Get the transition controller.
let transitionController = self.transitionController(forDocumentURL: documentURL)
```

To enable the loading animation, assign a [`Progress`](https://developer.apple.com/documentation/foundation/progress) object to the transition controller when you begin to load the document.

```swift
// Set up loading animation.
transitionController.loadingProgress = doc.loadProgress
```

Increment the progress as the document loads, making sure to mark it as complete as soon as loading finishes. To simulate slow, incremental loading in the sample code project, uncomment the [`TextDocument`](x-source-tag://TextDocument) class's `read(from:)` method.

To enable the transition animation, set the transition controller's target view and pass it to the [`TextDocumentViewController`](textDocumentViewController) object.

```swift
// Set up transition animation.
transitionController.targetView = documentViewController.textView
documentViewController.transitionController = transitionController
```

The text document view controller wraps the transition controller in a [`DocumentBrowserTransitioningDelegate`](DocumentBrowserTransitioningDelegate), and assigns the resulting delegate to its [`transitioningDelegate`](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621421-transitioningdelegate) property.

``` swift
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
```

The system then uses the transition animation when modally presenting the text view.
