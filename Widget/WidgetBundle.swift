//
//  WidgetBundle.swift
//  Widget
//
//  Created by huangfeng on 3/23/26.
//  Copyright © 2026 Fin. All rights reserved.
//

import WidgetKit
import SwiftUI

@main
struct BarkWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentMessagesWidget()
        #if canImport(ActivityKit)
        barkLiveActivityWidget
        #endif
    }

    #if canImport(ActivityKit)
    @WidgetBundleBuilder
    var barkLiveActivityWidget: some Widget {
        if #available(iOS 16.1, *) {
            BarkLiveActivity()
        }
    }
    #endif
}
