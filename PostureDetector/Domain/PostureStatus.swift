//
//  PostureStatus.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

enum PostureStatus {
    case unknown
    case good
    case forwardLean
    case sidewaysLean
    case poorPosture

    var description: String {
        switch self {
        case .unknown: return "Waiting for data..."
        case .good: return "Good Posture ✓"
        case .forwardLean: return "Leaning Forward"
        case .sidewaysLean: return "Leaning Sideways"
        case .poorPosture: return "Poor Posture"
        }
    }

    var color: String {
        switch self {
        case .unknown: return "gray"
        case .good: return "green"
        case .forwardLean, .sidewaysLean, .poorPosture: return "red"
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .good:
            return [Color.green.opacity(0.6), Color.blue.opacity(0.6)]
        case .forwardLean, .sidewaysLean, .poorPosture:
            return [Color.red.opacity(0.6), Color.orange.opacity(0.6)]
        case .unknown:
            return [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]
        }
    }
}
