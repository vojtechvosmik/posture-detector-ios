//
//  View+.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

extension View {
    func tab(symbol: SFSymbol, title: String) -> some View {
        tabItem {
            Image(symbol: symbol)
                .font(.system(size: 5))

            Text(title)
        }
    }
}
