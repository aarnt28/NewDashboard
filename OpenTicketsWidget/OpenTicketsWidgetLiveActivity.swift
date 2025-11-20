//
//  OpenTicketsWidgetLiveActivity.swift
//  OpenTicketsWidget
//
//  Created by Aaron Turner on 11/19/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct OpenTicketsWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct OpenTicketsWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OpenTicketsWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension OpenTicketsWidgetAttributes {
    fileprivate static var preview: OpenTicketsWidgetAttributes {
        OpenTicketsWidgetAttributes(name: "World")
    }
}

extension OpenTicketsWidgetAttributes.ContentState {
    fileprivate static var smiley: OpenTicketsWidgetAttributes.ContentState {
        OpenTicketsWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: OpenTicketsWidgetAttributes.ContentState {
         OpenTicketsWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: OpenTicketsWidgetAttributes.preview) {
   OpenTicketsWidgetLiveActivity()
} contentStates: {
    OpenTicketsWidgetAttributes.ContentState.smiley
    OpenTicketsWidgetAttributes.ContentState.starEyes
}
