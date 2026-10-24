//
//  SceneDelegate.swift
//  Bark
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var appDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black

        if UIDevice.current.userInterfaceIdiom == .pad {
            let splitViewController = BarkSplitViewController(style: .doubleColumn)
            window.rootViewController = BarkSnackbarController(rootViewController: splitViewController)
        } else {
            window.rootViewController = BarkSnackbarController(
                rootViewController: BarkTabBarController()
            )
        }

        self.window = window
        window.makeKeyAndVisible()

        if let url = connectionOptions.urlContexts.first?.url {
            handle(url: url)
        }
        if let response = connectionOptions.notificationResponse,
           response.actionIdentifier != UNNotificationDismissActionIdentifier
        {
            appDelegate?.handleNotification(
                userInfo: response.notification.request.content.userInfo
            )
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Setting -1 clears the badge without removing delivered notifications.
        UIApplication.shared.applicationIconBadgeNumber = -1

        Task {
            await appDelegate?.processPendingMessages()
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handle(url: url)
    }

    @discardableResult
    func handle(url: URL) -> Bool {
        if handleWidgetDeepLink(url) {
            return true
        }
        if handleLiveActivityDeepLink(url) {
            return true
        }

        if url.scheme?.lowercased() == "bark" && url.host?.lowercased() == "addserver" {
            // 提取参数
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let address = queryItems?.first(where: { $0.name == "address" })?.value

            // 处理添加服务器的逻辑
            if let serverAddress = try? address?.asURL() {
                let server = Server(address: serverAddress.absoluteString, key: "")
                ServerManager.shared.addServer(server: server)
                ServerManager.shared.setCurrentServer(serverId: server.id)
                ServerManager.shared.syncAllServers()
                HUDSuccess("AddedSuccessfully".localized)
            }
            return true
        }
        return false
    }

    private func handleWidgetDeepLink(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "bark", url.host?.lowercased() == "history" else {
            return false
        }

        Client.shared.currentTabPage = .messageHistory
        return true
    }

    private func handleLiveActivityDeepLink(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "bark", url.host?.lowercased() == "liveactivity" else {
            return false
        }
        
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let action = queryItems?.first(where: { $0.name == "action" })?.value?.lowercased() ?? "start"
            let id = queryItems?.first(where: { $0.name == "id" })?.value ?? UUID().uuidString
            let title = queryItems?.first(where: { $0.name == "title" })?.value ?? "Bark"
            let message = queryItems?.first(where: { $0.name == "message" })?.value
            let progressStr = queryItems?.first(where: { $0.name == "progress" })?.value
            let progress = progressStr.flatMap { Double($0) }
            let status = queryItems?.first(where: { $0.name == "status" })?.value
            let icon = queryItems?.first(where: { $0.name == "icon" })?.value
            
            switch action {
            case "start":
                _ = BarkLiveActivityManager.shared.startLiveActivity(
                    id: id,
                    title: title,
                    message: message,
                    progress: progress,
                    status: status,
                    iconName: icon
                )
                HUDSuccess("Live Activity Started")
            case "update":
                BarkLiveActivityManager.shared.updateLiveActivity(
                    id: id,
                    title: title,
                    message: message,
                    progress: progress,
                    status: status,
                    iconName: icon
                )
            case "end", "stop":
                BarkLiveActivityManager.shared.endLiveActivity(id: id)
                HUDSuccess("Live Activity Ended")
            default:
                break
            }
            return true
        }
        #endif
        return false
    }
}
