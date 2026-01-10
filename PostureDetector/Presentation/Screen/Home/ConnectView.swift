//
//  ConnectView.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

struct ConnectView: View {
    
    var body: some View {
        VStack(spacing: 15) {
            VStack(spacing: 10) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)

                Text("Connect your AirPods")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("To get posture tips, please connect your AirPods Pro or AirPods Max.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 10)

            Divider()
                .background(Color.white.opacity(1.8))

            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 12, height: 12)

                Text("Waiting for AirPods..")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
        .padding(25)
    }
}
