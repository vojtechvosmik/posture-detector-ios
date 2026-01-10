//
//  ErrorView.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)

            Text(message)
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Make sure your AirPods Pro or AirPods Max are connected")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(25)
    }
}
