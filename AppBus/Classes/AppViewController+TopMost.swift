#if os(iOS) || os(tvOS)
    import UIKit

    extension UIViewController {
        /// Returns the current application's top most view controller.
        open class var topMost: UIViewController? {
            let windows = UIApplication.shared.windows
            var rootViewController: UIViewController?
            for window in windows {
                if let windowRootViewController = window.rootViewController, window.isKeyWindow {
                    rootViewController = windowRootViewController
                    break
                }
            }

            return self.topMost(of: rootViewController)
        }

        /// Returns the top most view controller from given view controller's stack.
        open class func topMost(of viewController: UIViewController?) -> UIViewController? {
            // presented view controller
            if let presentedViewController = viewController?.presentedViewController {
                return topMost(of: presentedViewController)
            }

            // UITabBarController
            if let tabBarController = viewController as? UITabBarController,
                let selectedViewController = tabBarController.selectedViewController {
                return topMost(of: selectedViewController)
            }

            // UINavigationController
            if let navigationController = viewController as? UINavigationController,
                let visibleViewController = navigationController.visibleViewController {
                return topMost(of: visibleViewController)
            }

            // UIPageController
            if let pageViewController = viewController as? UIPageViewController,
                pageViewController.viewControllers?.count == 1 {
                return topMost(of: pageViewController.viewControllers?.first)
            }

            // child view controller
            for subview in viewController?.view?.subviews ?? [] {
                if let childViewController = subview.next as? UIViewController {
                    return topMost(of: childViewController)
                }
            }

            return viewController
        }
    }

#else
    import AppKit

    // TODO: get topMostController
    extension NSViewController {
        /// Returns the current application's top most view controller.
        open class var topMost: NSViewController? {
            let windows = NSApplication.shared.windows
            var rootViewController: NSViewController?
            for window in windows {
                if let windowRootViewController = window.contentViewController, window.isKeyWindow {
                    rootViewController = windowRootViewController
                    break
                }
            }

            return self.topMost(of: rootViewController)
        }

        /// Returns the top most view controller from given view controller's stack.
        open class func topMost(of viewController: NSViewController?) -> NSViewController? {
            // presented view controller
            if let presentedViewController = viewController?.presentedViewControllers?.last {
                return topMost(of: presentedViewController)
            }

            // NSTabViewController
            if let tabViewController = viewController as? NSTabViewController {
                let tabViewItem = tabViewController.tabViewItems[tabViewController.selectedTabViewItemIndex]
                if let selectedViewController = tabViewItem.viewController {
                    return topMost(of: selectedViewController)
                }
            }

            // NSPageController
            if let pageController = viewController as? NSPageController {
                return topMost(of: pageController.selectedViewController)
            }

            // child view controller
            for subview in viewController?.view.subviews ?? [] {
                if let childViewController = subview.nextResponder as? NSViewController {
                    return topMost(of: childViewController)
                }
            }

            return viewController
        }
    }

#endif
