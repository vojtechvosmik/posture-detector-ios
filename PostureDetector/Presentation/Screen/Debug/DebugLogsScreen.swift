//
//  DebugLogsScreen.swift
//  PostureDetector
//
//  Debug logs viewer
//

import SwiftUI

struct DebugLogsScreen: View {
    @State private var logContents = ""
    @State private var autoRefresh = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header controls
            HStack {
                Button(action: refreshLogs) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Toggle("Auto", isOn: $autoRefresh)
                    .toggleStyle(.button)

                Spacer()

                Button(action: clearLogs) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button(action: shareLogs) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            #if DEBUG
            // Seeds intraday samples so the deep coach can be exercised without
            // waiting two weeks for real ones. Debug builds only.
            HStack {
                Button {
                    PostureSampleStore.shared.seedDemoSamples()
                    logContents = "Seeded 20 days of intraday samples.\n" + logContents
                } label: {
                    Label("Seed deep-analysis data", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)
                .tint(.purple)

                Spacer()

                Button {
                    PostureSampleStore.shared.clearSamples()
                    logContents = "Cleared intraday samples.\n" + logContents
                } label: {
                    Label("Clear samples", systemImage: "trash.slash")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            #endif

            Divider()

            // Log viewer
            ScrollViewReader { proxy in
                ScrollView {
                    Text(logContents)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                        .id("logs")
                }
                .onChange(of: logContents) { _ in
                    if autoRefresh {
                        withAnimation {
                            proxy.scrollTo("logs", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .navigationTitle("Debug Logs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshLogs()
        }
        .onReceive(timer) { _ in
            if autoRefresh {
                refreshLogs()
            }
        }
    }

    private func refreshLogs() {
        logContents = DebugLogger.shared.getLogContents()
    }

    private func clearLogs() {
        DebugLogger.shared.clearLogs()
        refreshLogs()
    }

    private func shareLogs() {
        guard let url = DebugLogger.shared.getLogFileURL() else { return }

        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
