# PostureDetector - AirPods Posture Monitoring App

A SwiftUI iOS app that uses AirPods Pro or AirPods Max motion sensors to detect and alert you about bad posture.

## Features

- **Real-time Posture Detection**: Uses AirPods' built-in accelerometer and gyroscope
- **Auto Calibration**: Good posture is automatically defined as pitch ≈ 0° and roll ≈ 0° (head centered and level)
- **Visual Feedback**:
  - Dynamic UI with color changes based on posture status
  - Animated human body visualization showing your current posture
- **Live Metrics**: See pitch and roll angles in real-time
- **Multiple Posture States**: Detects forward lean, sideways lean, and combined poor posture
- **Background Monitoring**: Continues tracking even when app is in background
- **Push Notifications**: Get alerted when your posture becomes bad (max once per minute)
- **Live Activity on Lock Screen**: Real-time posture status displayed on lock screen and Dynamic Island (iOS 16.1+)

## Requirements

- iOS 14.0+
- AirPods Pro (1st or 2nd gen) or AirPods Max
- Xcode 14.0+
- Swift 5.5+

## How to Use

1. **Open in Xcode**:
   - Double-click `PostureDetector.xcodeproj` to open the project in Xcode
   - Select your development team in Signing & Capabilities
   - Connect your iPhone and select it as the run destination

2. **Build and Run**:
   - Press Cmd+R or click the Play button in Xcode
   - The app will install on your iPhone

3. **Grant Permissions**:
   - Allow notifications when prompted
   - Allow motion sensor access

4. **Connect AirPods**:
   - Connect your AirPods Pro or AirPods Max to your iPhone
   - Make sure they're properly fitted in your ears

5. **Start Monitoring**:
   - Launch the app
   - Tap "Start Monitoring"
   - The app automatically recognizes good posture when your head is centered (pitch and roll around 0°)

6. **Get Feedback**:
   - **In-app**: Animated body shows your posture in real-time
   - **Lock screen**: Live Activity displays current posture status
   - **Dynamic Island**: Posture status in Dynamic Island (iPhone 14 Pro+)
   - **Notifications**: Alerts when posture becomes bad (works in background)
   - **Background color**: Green = good posture, Red = bad posture
   - **Visual metrics**: See exact pitch and roll angles

## How It Works

The app uses `CMHeadphoneMotionManager` from CoreMotion framework to access AirPods' motion data:

- **Pitch**: Detects forward/backward head tilt (neck strain indicator)
- **Roll**: Detects left/right head tilt (asymmetric posture)
- **Target Calibration**: Good posture is defined as pitch ≈ 0° and roll ≈ 0° (head level and centered)
- **Thresholds**: Alerts when deviation exceeds ~20° in pitch or ~15° in roll
- **Background Mode**: Uses audio background mode to keep monitoring active
- **Smart Notifications**: Throttled to max one per minute to avoid spam
- **Live Activities**: Real-time updates on lock screen with color-coded status and metrics
  - Optimized with 1-second stale date for fastest possible updates
  - Relevance score prioritizes bad posture updates
  - Note: iOS applies system-level throttling to preserve battery

## Project Structure

```
PostureDetector/
├── PostureDetector.xcodeproj/     # Xcode project file
├── PostureDetector/               # Source files
│   ├── PostureDetectorApp.swift   # App entry point
│   ├── ContentView.swift          # Main UI
│   ├── PostureMonitor.swift       # Motion tracking, notifications & Live Activities
│   ├── PostureVisualizer.swift    # Animated body visualization
│   ├── PostureLiveActivity.swift  # Lock screen Live Activity widget
│   ├── Assets.xcassets/           # App icons and assets
│   └── Preview Content/           # SwiftUI preview assets
└── README.md                      # This file
```

## Customization

You can adjust sensitivity in `PostureMonitor.swift`:

```swift
private let pitchThreshold: Double = 0.35  // Adjust for forward lean sensitivity
private let rollThreshold: Double = 0.26   // Adjust for sideways lean sensitivity
```

## Limitations

- Only works with AirPods Pro and AirPods Max (standard AirPods don't have motion sensors)
- Requires iOS 14.0 or later
- Motion tracking only works while AirPods are worn
- Accuracy depends on proper AirPods fit
- Must test on real device (motion sensors don't work in simulator)

## Privacy

The app only accesses AirPods motion sensor data locally on your device. No data is collected or transmitted.

The app includes the required `NSMotionUsageDescription` privacy permission in the project settings.

## License

This is a sample project for educational purposes.
