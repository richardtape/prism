//
//  AudioLevelMeterView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import SwiftUI

/// Lightweight horizontal audio level meter for the status panel.
struct AudioLevelMeterView: View {
    let level: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: proxy.size.width * CGFloat(clampedLevel))
            }
        }
        .frame(height: 6)
    }

    private var clampedLevel: Double {
        min(max(level, 0), 1)
    }
}

#Preview {
    AudioLevelMeterView(level: 0.4)
        .frame(width: 200)
}
