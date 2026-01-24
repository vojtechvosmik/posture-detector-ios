//
//  BluetoothMonitor.swift
//  PostureDetector
//
//  Monitors AirPods connections by actually testing motion data availability
//

import Foundation
import AVFoundation
import Combine
import CoreMotion
import AudioToolbox

enum AirPodsConnectionState {
    case disconnected              // No AirPods detected
    case connectedElsewhere       // AirPods present but connected to another device
    case connectedAndActive       // AirPods connected and providing motion data
}

class BluetoothMonitor: NSObject, ObservableObject {
    @Published var connectedDeviceName: String?
    #if targetEnvironment(simulator)
    @Published var connectionState: AirPodsConnectionState = .connectedAndActive
    #else
    @Published var connectionState: AirPodsConnectionState = .disconnected
    #endif

    private var routeChangeObserver: NSObjectProtocol?
    private var checkTimer: Timer?
    private weak var postureMonitor: PostureMonitor?
    private let testMotionManager = CMHeadphoneMotionManager()
    private var lastMotionDataTime: Date?
    private var isTestingConnection = false

    init(postureMonitor: PostureMonitor) {
        self.postureMonitor = postureMonitor
        super.init()

        #if targetEnvironment(simulator)
        self.connectedDeviceName = "AirPods Pro (Simulator)"
        #endif

        setupAudioSession()
        startMonitoring()
        checkConnection()
    }

    deinit {
        stopMonitoring()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[BluetoothMonitor] Failed to setup audio session: \(error)")
        }
    }

    private func startMonitoring() {
        // Monitor audio route changes
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }

        // Periodic check for actual motion data
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkConnection()
        }
    }

    private func stopMonitoring() {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        checkTimer?.invalidate()
        checkTimer = nil
        testMotionManager.stopDeviceMotionUpdates()
    }

    func checkConnection() {
        #if targetEnvironment(simulator)
        // Simulator mode - always show as connected
        connectionState = .connectedAndActive
        connectedDeviceName = "AirPods Pro (Simulator)"
        return
        #endif

        // Don't start multiple simultaneous checks
        guard !isTestingConnection else { return }

        // Check if we have Bluetooth audio output to this device
        let hasBluetoothAudio = checkBluetoothAudioRoute()

        if hasBluetoothAudio {
            // We have Bluetooth audio - test if we can get motion data
            testActualMotionData()
        } else {
            // No Bluetooth audio - check if AirPods exist elsewhere
            //testForConnectedElsewhere()
            updateConnectionState(.connectedElsewhere)
        }
    }

    private func testActualMotionData() {
        isTestingConnection = true
        lastMotionDataTime = nil

        testMotionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self else { return }

            if let error = error {
                print("[BluetoothMonitor] Motion test error: \(error.localizedDescription)")
                self.testMotionManager.stopDeviceMotionUpdates()
                self.isTestingConnection = false
                self.updateConnectionState(.disconnected)
                return
            }

            if motion != nil {
                // We received actual motion data - AirPods are connected and working
                self.lastMotionDataTime = Date()
                self.testMotionManager.stopDeviceMotionUpdates()
                self.isTestingConnection = false
                self.updateConnectionState(.connectedAndActive)
            }
        }

        // Timeout after 1 second - if no data received, consider disconnected
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            self.testMotionManager.stopDeviceMotionUpdates()
            self.isTestingConnection = false

            if self.lastMotionDataTime == nil {
                // No motion data received within timeout - check if connected elsewhere
                print("[BluetoothMonitor] No motion data received - checking if connected elsewhere")
                //self.testForConnectedElsewhere()
                // TODO
            }
        }
    }

    private func checkBluetoothAudioRoute() -> Bool {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute

        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP ||
               output.portType == .bluetoothLE ||
               output.portType == .bluetoothHFP {
                return true
            }
        }

        return false
    }

    private func updateConnectionState(_ newState: AirPodsConnectionState) {
        guard connectionState != newState else { return }

        DispatchQueue.main.async {
            self.connectionState = newState

            switch newState {
            case .disconnected:
                self.connectedDeviceName = nil
                self.postureMonitor?.isConnected = false
                print("[BluetoothMonitor] AirPods disconnected")

            case .connectedElsewhere:
                self.connectedDeviceName = "AirPods"
                self.postureMonitor?.isConnected = false
                print("[BluetoothMonitor] AirPods detected but connected to another device")

            case .connectedAndActive:
                self.updateDeviceName()
                self.postureMonitor?.isConnected = true
                print("[BluetoothMonitor] AirPods connected and active: \(self.connectedDeviceName ?? "Unknown")")
            }
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        print("[BluetoothMonitor] Route change reason: \(reason.rawValue)")

        switch reason {
        case .newDeviceAvailable:
            // Device connected - check if motion data is available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.checkConnection()
            }
        case .oldDeviceUnavailable:
            // Device disconnected - immediately mark as disconnected
            updateConnectionState(.disconnected)
        default:
            // Other changes - recheck connection
            checkConnection()
        }
    }

    private func updateDeviceName() {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute

        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP ||
               output.portType == .bluetoothLE ||
               output.portType == .bluetoothHFP {
                connectedDeviceName = output.portName
                return
            }
        }

        connectedDeviceName = "AirPods"
    }
}
