//
//  RoutePickerView.swift
//  PostureDetector
//
//  SwiftUI wrapper for AVRoutePickerView
//

import SwiftUI
import AVKit

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
