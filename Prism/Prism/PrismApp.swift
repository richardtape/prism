//
//  PrismApp.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-05.
//

import SwiftUI

@main
struct PrismApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsWindowView()
        }
    }
}
