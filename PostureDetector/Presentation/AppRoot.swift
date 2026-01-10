//
//  AppRoot.swift
//  PostureDetector
//
//  Created by Vojtěch Vošmík on 10.01.2026.
//

import SwiftUI

struct AppRoot: View {

    var body: some View {
        TabView {
            homeTab
            calendarTab
            moreTab
        }
    }

    @ViewBuilder private var homeTab: some View {
        NavigationView {
            HomeScreen()
        }.tab(
            symbol: .figureStand,
            title: "Overview"
        )
    }

    @ViewBuilder private var calendarTab: some View {
        NavigationView {
            CalendarScreen()
        }.tab(
            symbol: .calendar,
            title: "Calendar"
        )
    }

    @ViewBuilder private var moreTab: some View {
        NavigationView {
            MoreScreen()
        }.tab(
            symbol: .ellipsis,
            title: "More"
        )
    }
}
