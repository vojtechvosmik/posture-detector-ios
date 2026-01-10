//
//  PostureAttributes.swift
//  PostureDetector
//
//  Shared PostureAttributes for Live Activity (used by both app and widget)
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct PostureAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var postureStatus: String
        public var pitch: Double
        public var roll: Double
        public var timestamp: Date

        public init(postureStatus: String, pitch: Double, roll: Double, timestamp: Date) {
            self.postureStatus = postureStatus
            self.pitch = pitch
            self.roll = roll
            self.timestamp = timestamp
        }
    }

    public init() {}
}
#endif
