//
//  StatusPanelController.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import AppKit
import SwiftUI

/// Manages the menu-bar anchored status panel that replaces a standard NSPopover.
final class StatusPanelController {
    private let panel: NSPanel
    private let hostingView: NSHostingView<AnyView>
    private let anchorSpacing: CGFloat = 2

    /// Creates a panel controller hosting the provided SwiftUI view.
    init(rootView: AnyView) {
        hostingView = NSHostingView(rootView: rootView)
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 240),
            styleMask: [.titled, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: true
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace]
        panel.contentView = hostingView
    }

    /// Toggles panel visibility relative to the provided status item button.
    func toggle(relativeTo button: NSStatusBarButton) {
        if panel.isVisible {
            close()
        } else {
            show(relativeTo: button)
        }
    }

    /// Shows the panel and positions it under the status item button.
    func show(relativeTo button: NSStatusBarButton) {
        positionPanel(relativeTo: button)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Closes the panel if it is visible.
    func close() {
        panel.orderOut(nil)
    }

    private func positionPanel(relativeTo button: NSStatusBarButton) {
        guard let window = button.window, let screen = window.screen else { return }

        let buttonFrame = window.convertToScreen(button.frame)
        let panelSize = panel.frame.size
        let visibleFrame = screen.visibleFrame

        var x = buttonFrame.midX - panelSize.width / 2
        x = min(max(x, visibleFrame.minX), visibleFrame.maxX - panelSize.width)

        var y = buttonFrame.minY - panelSize.height - anchorSpacing
        if y < visibleFrame.minY {
            y = buttonFrame.maxY + anchorSpacing
        }

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
