//
//  SFSymbol.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

enum SFSymbol: String {
    case figureStand = "figure.stand"
    case calendar = "calendar"
    case ellipsis = "ellipsis"
    case airpodspro = "airpodspro"
}

extension Image {
    init(symbol: SFSymbol) {
        self.init(systemName: symbol.rawValue)
    }
}
