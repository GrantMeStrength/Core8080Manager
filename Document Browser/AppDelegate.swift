/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An application delegate that support for opening shared documents.
*/

import UIKit
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ app: UIApplication, open inputURL: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // Reveal and import the document at the URL.
        guard let documentBrowserViewController = window?.rootViewController as? DocumentBrowserViewController else {
            fatalError("*** The root view is not a document browser! ***")
        }

        documentBrowserViewController.revealDocument(at: inputURL, importIfNeeded: true) { (revealedDocumentURL, error) in
            
            guard error == nil else {
                os_log("*** Failed to reveal the document at %@. Error: %@. ***",
                       log: OSLog.default,
                       type: .error,
                       inputURL as CVarArg,
                       error! as CVarArg)
                return
            }
            
            guard let url = revealedDocumentURL else {
                os_log("*** No URL revealed. ***",
                       log: OSLog.default,
                       type: .error)
                
                return
            }
            
            // You can do something
            // with the revealed document here.
            os_log("==> Revealed URL: %@.",
                   log: OSLog.default,
                   type: .debug,
                   url.path)
            
            // Present the Document View Controller for the revealed URL.
            documentBrowserViewController.presentDocument(at: revealedDocumentURL!)
        }

        return true
    }
}

