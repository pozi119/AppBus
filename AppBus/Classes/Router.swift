//
//  Router.swift
//  AppBus
//
//  Created by Valo on 2019/9/11.
//

import Foundation

#if os(iOS) || os(tvOS)
    import UIKit
    typealias APPViewController = UIViewController
#else
    import AppKit
    typealias APPViewController = NSViewController
#endif

open class Page {
    enum Method {
        case push, present, pop, dismiss
    }

    var type: APPViewController.Type?
    var name: String?
    var storyboard: String?
    var bundle: Bundle?
    var parameters: [String: Any] = [:]
    var method: Method = .push

    /// (willShowController, topMostController or topMostController.navigationController)
    var willShow: ((APPViewController, APPViewController?) -> Void)?
    var completion: (() -> Void)?

    private var _viewController: APPViewController?
    var viewController: APPViewController? {
        get {
            if _viewController != nil { return _viewController }
            if type != nil {
                _viewController = type!.init()
            } else if name != nil {
                if storyboard == nil {
                    _viewController = APPViewController(nibName: name!, bundle: bundle)
                } else {
                    #if os(iOS) || os(tvOS)
                        let sb = UIStoryboard(name: name!, bundle: bundle)
                        _viewController = sb.instantiateViewController(withIdentifier: name!)
                    #else
                        let sb = NSStoryboard(name: name!, bundle: bundle)
                        _viewController = sb.instantiateController(withIdentifier: name!) as? APPViewController
                    #endif
                }
            }
            if _viewController != nil { _viewController!.setValuesForKeys(parameters) }
            return _viewController
        }
        set {
            _viewController = newValue
        }
    }

    init(_ type: APPViewController.Type, parameters: [String: Any] = [:]) {
        self.type = type
        self.parameters = parameters
    }

    init(_ name: String, storyboard: String, bundle: Bundle? = nil, parameters: [String: Any] = [:]) {
        self.name = name
        self.storyboard = storyboard
        self.bundle = bundle
        self.parameters = parameters
    }

    #if os(iOS) || os(tvOS)

        func show() -> Bool {
            guard let topMostViewController = APPViewController.topMost else { return false }

            switch method {
            case .push:
                guard let vc = viewController, let navigationController = topMostViewController.navigationController else { return false }
                if willShow != nil { willShow!(vc, navigationController) }
                navigationController.pushViewController(vc, animated: true)

            case .present:
                guard let vc = viewController else { return false }
                if willShow != nil { willShow!(vc, topMostViewController) }
                topMostViewController.present(vc, animated: true, completion: completion)

            case .pop:
                guard let navigationController = topMostViewController.navigationController else { return false }
                if let vc = viewController {
                    let filtered = navigationController.viewControllers.filter { $0.isKind(of: vc.classForCoder) }
                    if let targetController = filtered.first {
                        targetController.setValuesForKeys(parameters)
                        navigationController.popToViewController(targetController, animated: true)
                        return true
                    }
                }
                navigationController.popViewController(animated: true)

            case .dismiss:
                if let vc = viewController {
                    var count = 0
                    var targetController: APPViewController?
                    var controller: APPViewController? = topMostViewController
                    while controller != nil, targetController != nil {
                        if controller!.isKind(of: vc.classForCoder) {
                            targetController = controller
                        } else {
                            controller = controller!.presentedViewController
                            count += 1
                        }
                    }
                    if targetController != nil {
                        for _ in 0 ..< count - 1 {
                            topMostViewController.dismiss(animated: false, completion: nil)
                        }
                    }
                }
                topMostViewController.dismiss(animated: true, completion: completion)
            }
            return true
        }
    #endif
}

/// URL Router
public final class Router {
    fileprivate static let shared: Router = Router()

    public typealias Handler = (_ path: String, _ parameters: [String: String]) -> Bool

    private var routers: [String: Any] = [:]
}

extension Router {
    /// register url path for handler
    public class func register(_ path: String, handler: @escaping Handler) {
        shared.routers[path] = handler
    }

    /// register url path for page
    public class func register(_ path: String, page: Page) {
        shared.routers[path] = page
    }

    /// deregister provider
    public class func deregister(_ path: String) {
        shared.routers.removeValue(forKey: path)
    }
}

extension Router {
    /// open url
    ///
    /// - Parameters:
    ///   - url: url as follows
    ///     - `app://provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
    ///     - `app://www.xxx.com/provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
    ///     - `app://192.168.11.2/provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`
    /// - Returns: success or not
    @discardableResult
    public class func open(_ url: URL) -> Bool {
        if let parameters = url.routerParameters {
            let item = shared.routers[parameters.path]
            switch item {
            case let item as Page:
                #if os(iOS) || os(watchOS)
                    return item.show()
                #else
                    return false
                #endif
            case let item as Handler:
                return item(parameters.path, parameters.parameters)
            default: break
            }
        }
        if let request = url.serviceRequest {
            _ = Service.sync(request)
            return true
        }
        return false
    }

    /// open url
    ///
    /// - Parameters:
    ///   - url: url as follows
    ///     - `app://provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
    ///     - `app://www.xxx.com/provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
    ///     - `app://192.168.11.2/provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`
    /// - Returns: success or not
    @discardableResult
    public class func open(_ url: String) -> Bool {
        guard let _url = URL(string: url) else { return false }
        return open(_url)
    }
}
