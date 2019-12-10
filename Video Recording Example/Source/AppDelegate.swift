//
//  AppDelegate.swift
//  Video Recording Example
//
//  Created by Nathan Beaumont on 12/9/19.
//  Copyright © 2019 Nathan Beaumont. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let initialViewController = storyboard.instantiateViewController(withIdentifier: String(describing: HomeViewController.self))
        window?.rootViewController = initialViewController
        window?.makeKeyAndVisible()

        return true
    }
}

