/*
 <samplecode>
 <abstract>
 Extensions that add convenience methods to SwiftUI.
 </abstract>
 </samplecode>
 */

import SwiftUI
import Combine

extension Color {
    static var listHeaderBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #elseif os(watchOS)
        return Color(uiColor: .clear)
        #endif
    }
    
    static var gridItemBackground: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #elseif os(watchOS)
        return Color.gray
        #endif
    }
}

extension NotificationCenter {
    var storeDidChangePublisher: Publishers.ReceiveOn<NotificationCenter.Publisher, DispatchQueue> {
        return publisher(for: .cdcksStoreDidChange).receive(on: DispatchQueue.main)
    }
}
