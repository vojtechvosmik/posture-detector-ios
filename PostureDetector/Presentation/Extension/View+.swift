//
//  View+.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI
import UIKit

extension View {
    func tab(symbol: SFSymbol, title: String) -> some View {
        tabItem {
            Image(symbol: symbol)
                .font(.system(size: 5))

            Text(title)
        }
    }
}

// MARK: - Aura theme (adaptive light / dark)

/// Shared, appearance-adaptive palette for the "aurora" design language.
/// Accents read on both light and dark; neutral fills flip with the scheme.
enum Aura {
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    static let accent  = Color(red: 0.34, green: 0.50, blue: 1.0)
    static let violet  = Color(red: 0.55, green: 0.40, blue: 0.96)
    static let purple  = Color(red: 0.68, green: 0.42, blue: 1.0)
    static let orange  = Color(red: 1.0, green: 0.60, blue: 0.20)
    static let green   = dynamic(light: Color(red: 0.13, green: 0.70, blue: 0.46),
                                 dark:  Color(red: 0.28, green: 0.88, blue: 0.62))
    static let coral   = dynamic(light: Color(red: 0.96, green: 0.36, blue: 0.30),
                                 dark:  Color(red: 1.0,  green: 0.49, blue: 0.40))

    static func scoreColor(_ score: Int) -> Color {
        score >= 80 ? green : score >= 60 ? orange : coral
    }

    /// Hairline border for cards.
    static let cardStroke = dynamic(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.09))
    /// Neutral fill for off-state chips / tracks.
    static let softFill   = dynamic(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.08))
    static let hairline   = dynamic(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.10))
}

/// Full-bleed, appearance-adaptive aurora backdrop.
struct AuraBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark
                    ? [Color(red: 0.06, green: 0.06, blue: 0.14), Color(red: 0.03, green: 0.03, blue: 0.09)]
                    : [Color(red: 0.97, green: 0.97, blue: 1.0), Color(red: 0.93, green: 0.94, blue: 0.99)],
                startPoint: .top, endPoint: .bottom
            )
            blob(Color(red: 0.30, green: 0.50, blue: 1.0), 400, -120, -300)
            blob(Color(red: 0.62, green: 0.38, blue: 0.98), 420, 150, -40)
            blob(Color(red: 0.96, green: 0.46, blue: 0.72), 340, -110, 420)
        }
        .ignoresSafeArea()
    }

    private func blob(_ c: Color, _ size: CGFloat, _ x: CGFloat, _ y: CGFloat) -> some View {
        Circle().fill(c).frame(width: size, height: size)
            .blur(radius: 100)
            .opacity(scheme == .dark ? 0.18 : 0.13)
            .offset(x: x, y: y)
    }
}

/// Frosted glass card that adapts to light / dark automatically.
struct AuraCard: ViewModifier {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(Aura.cardStroke, lineWidth: 1))
    }
}

extension View {
    func auraCard(padding: CGFloat = 20, cornerRadius: CGFloat = 24) -> some View {
        modifier(AuraCard(padding: padding, cornerRadius: cornerRadius))
    }
}
