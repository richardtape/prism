//
//  SettingsSectionContainer.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import SwiftUI

/// Standard layout wrapper for settings sections.
struct SettingsSectionContainer<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            content
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsSectionContainer(title: "Example") {
        Text("Content")
    }
}
