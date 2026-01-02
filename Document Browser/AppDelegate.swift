/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An application delegate that support for opening shared documents.
*/

import UIKit
import os.log

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
    }

    // MARK: - Legacy Support (for devices not supporting scenes)

    func application(_ app: UIApplication, open inputURL: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

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

