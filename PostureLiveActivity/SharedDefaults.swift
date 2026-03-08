//
//  SharedDefaults.swift
//  PostureDetector
//
//  Shared App Group constants for data sharing between app and widget extension
//

import Foundation

enum SharedDefaults {
    static let appGroupIdentifier = "group.cz.peachdev.postureplus"
    static let postureHistoryKey = "postureHistory"

    static var sharedUserDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
