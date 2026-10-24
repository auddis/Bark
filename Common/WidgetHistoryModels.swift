//
//  WidgetHistoryModels.swift
//  Bark
//
//  Created by OpenCode on 2026/3/26.
//

import Foundation

enum WidgetHistoryConstants {
    static let appGroupIdentifier = "group.com.austinarnold.bark"
    static let snapshotFilename = "recent_messages_snapshot.json"
    static let widgetKind = "RecentMessagesWidget"
    static let displayLimit = 3
    static let snapshotRetentionLimit = 100
    static let bodyCharacterLimit = 500
}

private extension String {
    func trimmedForWidget(limit: Int = WidgetHistoryConstants.bodyCharacterLimit) -> String {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else {
            return normalized
        }
        return String(normalized.prefix(limit))
    }
}

struct WidgetHistoryMessage: Codable, Identifiable {
    let id: String
    let group: String?
    let title: String?
    let subtitle: String?
    let body: String?
    let image: String?
    let createDate: Date

    init(id: String,
         group: String?,
         title: String?,
         subtitle: String?,
         body: String?,
         image: String?,
         createDate: Date)
    {
        self.id = id
        self.group = group
        self.title = title
        self.subtitle = subtitle
        self.body = body?.trimmedForWidget()
        self.image = image
        self.createDate = createDate
    }
}

struct WidgetHistorySnapshot: Codable {
    let messages: [WidgetHistoryMessage]

    func recentMessages(in group: String?, limit: Int = WidgetHistoryConstants.displayLimit) -> [WidgetHistoryMessage] {
        let filteredMessages: [WidgetHistoryMessage]
        if let group {
            filteredMessages = messages.filter { $0.group == group }
        } else {
            filteredMessages = messages
        }

        return Array(filteredMessages.prefix(limit))
    }

    var availableGroups: [String] {
        messages.reduce(into: [String]()) { result, message in
            guard let group = message.group, !group.isEmpty, !result.contains(group) else {
                return
            }
            result.append(group)
        }
    }
}

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct BarkActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var message: String?
        public var progress: Double?
        public var status: String?
        public var iconName: String?
        public var updateDate: Date
        
        public init(
            title: String,
            message: String? = nil,
            progress: Double? = nil,
            status: String? = nil,
            iconName: String? = nil,
            updateDate: Date = Date()
        ) {
            self.title = title
            self.message = message
            self.progress = progress
            self.status = status
            self.iconName = iconName
            self.updateDate = updateDate
        }
    }
    
    public var activityId: String
    
    public init(activityId: String) {
        self.activityId = activityId
    }
}

@available(iOS 16.2, *)
public final class BarkLiveActivityManager {
    public static let shared = BarkLiveActivityManager()
    private init() {}
    
    public func startLiveActivity(
        id: String,
        title: String,
        message: String? = nil,
        progress: Double? = nil,
        status: String? = nil,
        iconName: String? = nil
    ) -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return nil
        }
        
        endLiveActivity(id: id)
        
        let attributes = BarkActivityAttributes(activityId: id)
        let state = BarkActivityAttributes.ContentState(
            title: title,
            message: message,
            progress: progress,
            status: status,
            iconName: iconName
        )
        
        do {
            let activity = try Activity<BarkActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: .token
            )
            
            Task {
                for await pushToken in activity.pushTokenUpdates {
                    let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
                    savePushToken(tokenString, for: id)
                }
            }
            return activity.id
        } catch {
            return nil
        }
    }
    
    public func updateLiveActivity(
        id: String,
        title: String? = nil,
        message: String? = nil,
        progress: Double? = nil,
        status: String? = nil,
        iconName: String? = nil
    ) {
        guard let activity = Activity<BarkActivityAttributes>.activities.first(where: { $0.attributes.activityId == id }) else {
            return
        }
        
        let currentState = activity.content.state
        let newState = BarkActivityAttributes.ContentState(
            title: title ?? currentState.title,
            message: message ?? currentState.message,
            progress: progress ?? currentState.progress,
            status: status ?? currentState.status,
            iconName: iconName ?? currentState.iconName
        )
        
        Task {
            await activity.update(.init(state: newState, staleDate: nil))
        }
    }
    
    public func endLiveActivity(id: String) {
        for activity in Activity<BarkActivityAttributes>.activities where activity.attributes.activityId == id {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    
    public func endAllLiveActivities() {
        for activity in Activity<BarkActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    
    private func savePushToken(_ token: String, for activityId: String) {
        let defaults = UserDefaults(suiteName: WidgetHistoryConstants.appGroupIdentifier)
        var tokens = defaults?.dictionary(forKey: "liveActivityPushTokens") as? [String: String] ?? [:]
        tokens[activityId] = token
        defaults?.set(tokens, forKey: "liveActivityPushTokens")
    }
}
#endif
