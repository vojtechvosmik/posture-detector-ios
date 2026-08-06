//
//  RoutePickerView.swift
//  PostureDetector
//
//  SwiftUI wrapper for AVRoutePickerView
//

import SwiftUI
import AVKit

/// Opens the system output picker from an ordinary SwiftUI button.
///
/// `AVRoutePickerView` only reacts to taps on its own glyph, so overlaying it
/// on a full-width button quietly does nothing for most of that button. This
/// keeps a zero-sized picker in the hierarchy and taps it programmatically.
struct RoutePickerTrigger: UIViewRepresentable {
    @Binding var isTriggered: Bool

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = false
        picker.isHidden = false
        picker.alpha = 0.01
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        guard isTriggered else { return }
        DispatchQueue.main.async {
            isTriggered = false
            uiView.subviews.compactMap { $0 as? UIButton }
                .first?
                .sendActions(for: .touchUpInside)
        }
    }
}

extension View {
    /// Presents the system output picker when `isPresented` flips to true.
    func routePicker(isPresented: Binding<Bool>) -> some View {
        background(
            RoutePickerTrigger(isTriggered: isPresented)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
    }
}

struct RoutePickerView: UIViewRepresentable {
    var tint: UIColor = .white
    var activeTint: UIColor = .white

    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = tint
        routePickerView.activeTintColor = activeTint
        routePickerView.prioritizesVideoDevices = false
        return routePickerView
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tint
        uiView.activeTintColor = activeTint
    }
}
