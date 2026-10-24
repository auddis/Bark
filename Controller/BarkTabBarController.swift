//
//  BarkTabBarController.swift
//  Bark
//
//  Created by huangfeng on 2024/8/20.
//  Copyright © 2024 Fin. All rights reserved.
//

import Material
import UIKit

class BarkTabBarController: StateRestoringTabBarContr {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBar.tintColor = BKColor.grey.darken4
        
        var controllers: [UIViewController] = [
            BarkNavigationController(rootViewController: HomeViewController(viewModel: HomeViewModel())),
            BarkNavigationController(rootViewController: MessageListViewController(viewModel: MessageListViewModel())),
            BarkNavigationController(rootViewController: MessageSettingsViewController(viewModel: MessageSettingsViewModel()))
        ]
        
        var tabBarItems = [
            UITabBarItem(title: "service".localized, image: UIImage(named: "baseline_gite_black_24pt"), tag: 0),
            UITabBarItem(title: "historyMessage".localized, image: Icon.history, tag: 1),
            UITabBarItem(title: "settings".localized, image: UIImage(named: "baseline_manage_accounts_black_24pt"), tag: 2)
        ]

        if #available(iOS 16.2, *) {
            let studioVC = LiveActivityStudioViewController()
            controllers.append(BarkNavigationController(rootViewController: studioVC))
            let activityIcon = UIImage(systemName: "sparkles") ?? UIImage(systemName: "bell.badge")
            tabBarItems.append(UITabBarItem(title: "Live Activity", image: activityIcon, tag: 3))
        }

        self.viewControllers = controllers
        for (index, viewController) in self.viewControllers!.enumerated() {
            viewController.tabBarItem = tabBarItems[index]
        }
    }
}
