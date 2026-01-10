//
//  HomeScreen.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

struct HomeScreen: View {
    @StateObject private var postureMonitor = PostureMonitor()
    @State private var isMonitoring = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                statusCard
                if isMonitoring && postureMonitor.isConnected {
                    MetricsView(
                        pitch: postureMonitor.pitch,
                        roll: postureMonitor.roll
                    )
                }
                controls
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .navigationTitle("Posture Detector")
    }

    @ViewBuilder private var statusCard: some View {
        ZStack {
            /*if let errorMessage = postureMonitor.errorMessage {
                ErrorView(message: errorMessage)
            } else if !postureMonitor.isConnected {
                ConnectView()
            } else {*/
                PostureVisualizer(
                    pitch: postureMonitor.pitch,
                    roll: postureMonitor.roll,
                    postureStatus: postureMonitor.postureStatus
                )
                .frame(height: 250)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                .blur(radius: isMonitoring ? 0 : 3)
            //}
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            LinearGradient(
                gradient: Gradient(colors: postureMonitor.postureStatus.backgroundColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .background(Color.white.opacity(0.4))
        .cornerRadius(20)
    }

    @ViewBuilder private var controls: some View {
        VStack(spacing: 15) {
            Button(action: {
                if isMonitoring {
                    postureMonitor.stopMonitoring()
                    isMonitoring = false
                } else {
                    postureMonitor.startMonitoring()
                    isMonitoring = true
                }
            }) {
                HStack {
                    Image(systemName: isMonitoring ? "stop.circle.fill" : "play.circle.fill")
                    Text(isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(isMonitoring ? .red : .blue)
                .cornerRadius(15)
            }
        }
    }
}
