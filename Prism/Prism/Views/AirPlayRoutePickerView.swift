//
//  AirPlayRoutePickerView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-08.
//

import AVKit
import SwiftUI

/// Wrapper for the system AirPlay route picker.
struct AirPlayRoutePickerView: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        return view
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}

#Preview {
    AirPlayRoutePickerView()
        .frame(width: 28, height: 28)
        .padding()
}
