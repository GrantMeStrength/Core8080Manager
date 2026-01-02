//
//  SceneDelegate.swift
//  Core8080
//
//  UIScene lifecycle support
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Create window for the scene
        window = UIWindow(windowScene: windowScene)

        // Load the main storyboard and set the root view controller
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let documentBrowserViewController = storyboard.instantiateInitialViewController() as? DocumentBrowserViewController {
            window?.rootViewController = documentBrowserViewController
            window?.makeKeyAndVisible()

            // Handle any URLs that were passed during launch
            if let urlContext = connectionOptions.urlContexts.first {
                _ = documentBrowserViewController.application(UIApplication.shared, open: urlContext.url, options: [:])
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let documentBrowserViewController = window?.rootViewController as? DocumentBrowserViewController,
              let urlContext = URLContexts.first else {
            return
        }

        _ = documentBrowserViewController.application(UIApplication.shared, open: urlContext.url, options: [:])
    }
}

// Extension to allow SceneDelegate to call AppDelegate's URL handling
extension DocumentBrowserViewController {
    func application(_ app: UIApplication, open inputURL: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Reveal and import the document at the URL.
        self.revealDocument(at: inputURL, importIfNeeded: true) { (revealedDocumentURL, error) in

            guard error == nil else {
                return
            }

            guard let url = revealedDocumentURL else {
                return
            }

            // Present the Document View Controller for the revealed URL.
            self.presentDocument(at: revealedDocumentURL!)
        }

        return true
    }
}
