//
//  LiveActivityStudioView.swift
//  Bark
//
//  Created by Austin Arnold on 10/24/26.
//  Copyright © 2026 Bark. All rights reserved.
//

import SwiftUI
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif

@available(iOS 16.2, *)
struct LiveActivityStudioView: View {
    @State private var activityId: String = "backup-task"
    @State private var title: String = "Database Backup"
    @State private var message: String = "Uploading snapshot to cloud..."
    @State private var status: String = "In Progress"
    @State private var hasProgress: Bool = true
    @State private var progress: Double = 0.65
    @State private var selectedIcon: String = "server.rack"
    @State private var previewMode: PreviewMode = .dynamicIslandExpanded
    @State private var isRunning: Bool = false
    @State private var currentPushToken: String? = nil
    @State private var toastMessage: String? = nil
    @State private var showToast: Bool = false

    enum PreviewMode: String, CaseIterable, Identifiable {
        case dynamicIslandExpanded = "Island (Expanded)"
        case dynamicIslandCompact = "Island (Compact)"
        case lockScreen = "Lock Screen"
        var id: String { rawValue }
    }

    let presetIcons = [
        "server.rack", "arrow.down.circle.fill", "cloud.arrow.up.fill",
        "bell.fill", "bolt.fill", "flame.fill", "checkmark.circle.fill",
        "exclamationmark.triangle.fill", "gearshape.2.fill", "cpu.fill"
    ]

    let presetStatuses = [
        "In Progress", "Building", "Uploading", "Syncing", "Done", "Failed"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Preview Header & Mode Selector
                VStack(spacing: 12) {
                    Picker("Preview Mode", selection: $previewMode) {
                        ForEach(PreviewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // MARK: - Visual Canvas
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(uiColor: .systemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            )

                        VStack {
                            switch previewMode {
                            case .dynamicIslandExpanded:
                                dynamicIslandExpandedPreview
                            case .dynamicIslandCompact:
                                dynamicIslandCompactPreview
                            case .lockScreen:
                                lockScreenBannerPreview
                            }
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                    }
                    .padding(.horizontal)
                }

                // MARK: - Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: startOnDevice) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start on Device")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button(action: updateOnDevice) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Update")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .foregroundColor(.primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    HStack(spacing: 12) {
                        Button(action: endOnDevice) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("End Activity")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Button(action: endAllOnDevice) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("End All")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundColor(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal)

                // MARK: - Parameters Form
                VStack(alignment: .leading, spacing: 18) {
                    Text("Configuration")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 14) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Title").font(.caption).foregroundColor(.secondary)
                            TextField("Title", text: $title)
                                .textFieldStyle(StudioTextFieldStyle())
                        }

                        // Message
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Subtitle / Message").font(.caption).foregroundColor(.secondary)
                            TextField("Message", text: $message)
                                .textFieldStyle(StudioTextFieldStyle())
                        }

                        // Activity ID
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Activity ID").font(.caption).foregroundColor(.secondary)
                            TextField("Activity ID", text: $activityId)
                                .textFieldStyle(StudioTextFieldStyle())
                        }

                        // Status Badge
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Status Badge").font(.caption).foregroundColor(.secondary)
                            TextField("Status text", text: $status)
                                .textFieldStyle(StudioTextFieldStyle())

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(presetStatuses, id: \.self) { preset in
                                        Button(action: { status = preset }) {
                                            Text(preset)
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(status == preset ? Color.blue : Color.secondary.opacity(0.12))
                                                .foregroundColor(status == preset ? .white : .primary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        // Progress Slider
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Enable Progress Bar", isOn: $hasProgress)
                                .font(.subheadline)

                            if hasProgress {
                                HStack {
                                    Slider(value: $progress, in: 0.0...1.0)
                                    Text("\(Int(progress * 100))%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .frame(width: 44, alignment: .trailing)
                                }
                            }
                        }

                        // SF Symbol Icon Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon").font(.caption).foregroundColor(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(presetIcons, id: \.self) { icon in
                                        Button(action: { selectedIcon = icon }) {
                                            Image(systemName: icon)
                                                .font(.system(size: 20))
                                                .frame(width: 44, height: 44)
                                                .background(selectedIcon == icon ? Color.blue : Color.secondary.opacity(0.12))
                                                .foregroundColor(selectedIcon == icon ? .white : .primary)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal)
                }

                // MARK: - Code & Push Automation Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("Automation & Remote APNs")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 10) {
                        Button(action: copyDeepLink) {
                            HStack {
                                Image(systemName: "link")
                                Text("Copy Bark Deep Link")
                                Spacer()
                                Image(systemName: "doc.on.doc")
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button(action: copyCurlCommand) {
                            HStack {
                                Image(systemName: "terminal")
                                Text("Copy APNs cURL Command")
                                Spacer()
                                Image(systemName: "doc.on.doc")
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button(action: copyJsonPayload) {
                            HStack {
                                Image(systemName: "curlybraces")
                                Text("Copy APNs JSON Payload")
                                Spacer()
                                Image(systemName: "doc.on.doc")
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Live Activities")
        .overlay(
            Group {
                if showToast, let msg = toastMessage {
                    Text(msg)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .shadow(radius: 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 16)
                }
            },
            alignment: .top
        )
    }

    // MARK: - Visual Preview Views

    private var dynamicIslandExpandedPreview: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: selectedIcon)
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer()
                if !status.isEmpty {
                    Text(status)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.3))
                        .foregroundColor(.cyan)
                        .clipShape(Capsule())
                }
            }

            if !message.isEmpty {
                HStack {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    Spacer()
                }
            }

            if hasProgress {
                ProgressView(value: min(max(progress, 0.0), 1.0))
                    .tint(.blue)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }

    private var dynamicIslandCompactPreview: some View {
        HStack {
            Image(systemName: selectedIcon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
            Spacer()
            if hasProgress {
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            } else {
                Text(status.isEmpty ? title : status)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 210, height: 38)
        .background(Color.black)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
    }

    private var lockScreenBannerPreview: some View {
        HStack(spacing: 14) {
            Image(systemName: selectedIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    if !status.isEmpty {
                        Text(status)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                }

                if !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if hasProgress {
                    ProgressView(value: min(max(progress, 0.0), 1.0))
                        .tint(.blue)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
    }

    // MARK: - Actions

    private func startOnDevice() {
        let res = BarkLiveActivityManager.shared.startLiveActivity(
            id: activityId,
            title: title,
            message: message.isEmpty ? nil : message,
            progress: hasProgress ? progress : nil,
            status: status.isEmpty ? nil : status,
            iconName: selectedIcon
        )
        if res != nil {
            displayToast("🚀 Live Activity Started on Dynamic Island!")
            isRunning = true
        } else {
            displayToast("Failed: Live Activities disabled in Settings")
        }
    }

    private func updateOnDevice() {
        BarkLiveActivityManager.shared.updateLiveActivity(
            id: activityId,
            title: title,
            message: message.isEmpty ? nil : message,
            progress: hasProgress ? progress : nil,
            status: status.isEmpty ? nil : status,
            iconName: selectedIcon
        )
        displayToast("🔄 Live Activity Updated!")
    }

    private func endOnDevice() {
        BarkLiveActivityManager.shared.endLiveActivity(id: activityId)
        displayToast("⏹️ Live Activity Ended")
        isRunning = false
    }

    private func endAllOnDevice() {
        BarkLiveActivityManager.shared.endAllLiveActivities()
        displayToast("All Live Activities Cleared")
        isRunning = false
    }

    private func copyDeepLink() {
        var components = URLComponents()
        components.scheme = "bark"
        components.host = "liveactivity"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "action", value: "start"),
            URLQueryItem(name: "id", value: activityId),
            URLQueryItem(name: "title", value: title)
        ]
        if !message.isEmpty { items.append(URLQueryItem(name: "message", value: message)) }
        if hasProgress { items.append(URLQueryItem(name: "progress", value: String(format: "%.2f", progress))) }
        if !status.isEmpty { items.append(URLQueryItem(name: "status", value: status)) }
        if !selectedIcon.isEmpty { items.append(URLQueryItem(name: "icon", value: selectedIcon)) }
        components.queryItems = items

        let str = components.url?.absoluteString ?? ""
        UIPasteboard.general.string = str
        displayToast("Copied Deep Link URL")
    }

    private func copyCurlCommand() {
        let payload = generateApnsJson()
        let curl = """
        curl -v --http2 \\
          -H "apns-topic: com.austinarnold.bark.push-type.liveactivity" \\
          -H "apns-push-type: liveactivity" \\
          -H "apns-priority: 10" \\
          -d '\(payload)' \\
          https://api.push.apple.com/3/device/<YOUR_LIVE_ACTIVITY_TOKEN>
        """
        UIPasteboard.general.string = curl
        displayToast("Copied cURL Command")
    }

    private func copyJsonPayload() {
        UIPasteboard.general.string = generateApnsJson()
        displayToast("Copied APNs JSON Payload")
    }

    private func generateApnsJson() -> String {
        let ts = Int(Date().timeIntervalSince1970)
        let progVal = hasProgress ? "\(progress)" : "null"
        return """
        {
          "aps": {
            "timestamp": \(ts),
            "event": "update",
            "content-state": {
              "title": "\(title)",
              "message": "\(message)",
              "progress": \(progVal),
              "status": "\(status)",
              "iconName": "\(selectedIcon)"
            }
          }
        }
        """
    }

    private func displayToast(_ msg: String) {
        toastMessage = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showToast = false }
        }
    }
}

private struct StudioTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Hosting Controller for UIKit TabBar
@available(iOS 16.2, *)
class LiveActivityStudioViewController: UIHostingController<LiveActivityStudioView> {
    init() {
        super.init(rootView: LiveActivityStudioView())
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
