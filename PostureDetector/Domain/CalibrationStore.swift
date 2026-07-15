//
//  CalibrationStore.swift
//  PostureDetector
//
//  Stores the user's calibrated "neutral" head position so posture detection
//  is measured relative to how *they* actually sit, not a hardcoded zero.
//

import Foundation

enum CalibrationStore {
    private static let pitchKey = "calibrationPitch"
    private static let rollKey = "calibrationRoll"
    private static let calibratedKey = "hasCalibrated"
    private static let dateKey = "calibrationDate"

    /// Neutral pitch captured during calibration (radians). Defaults to 0.
    static var pitch: Double {
        UserDefaults.standard.double(forKey: pitchKey)
    }

    /// Neutral roll captured during calibration (radians). Defaults to 0.
    static var roll: Double {
        UserDefaults.standard.double(forKey: rollKey)
    }

    /// Whether the user has completed calibration at least once.
    static var isCalibrated: Bool {
        UserDefaults.standard.bool(forKey: calibratedKey)
    }

    static var calibratedAt: Date? {
        UserDefaults.standard.object(forKey: dateKey) as? Date
    }

    static func save(pitch: Double, roll: Double) {
        let defaults = UserDefaults.standard
        defaults.set(pitch, forKey: pitchKey)
        defaults.set(roll, forKey: rollKey)
        defaults.set(true, forKey: calibratedKey)
        defaults.set(Date(), forKey: dateKey)
    }

    static func reset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: pitchKey)
        defaults.removeObject(forKey: rollKey)
        defaults.removeObject(forKey: calibratedKey)
        defaults.removeObject(forKey: dateKey)
    }
}
