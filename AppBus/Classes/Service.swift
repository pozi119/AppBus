//
//  Service.swift
//  AppBus
//
//  Created by Valo on 2019/6/17.
//

import Foundation

// MARK: - Request

/// request initiated by customer
public class Request {
    private static var _id: UInt64 = 0

    /// request id, auto increment
    public let id: UInt64 = {
        Request._id += 1
        return Request._id
    }()

    /// provider name
    public var provider: String = ""

    /// provider action
    public var action: String = ""

    /// provider additional path
    public var path: String = ""

    /// timeout
    public var timeout: TimeInterval = 5

    /// parameters for action
    public var parameters: [String: Any] = [:]

    init() {}

    public init(provider: String, action: String) {
        self.provider = provider
        self.action = action
    }
}

extension Request: CustomStringConvertible {
    public var description: String {
        return "id:\(id) provider:\(provider) action:\(action) path:\(path) timeout:\(timeout) parameters:\(parameters)"
    }
}

// MARK: - Response

public struct Response {
    public let request: Request?

    public var data: Any?

    public var error: Error?

    public init(_ request: Request?, data: Any? = nil, error: Error? = nil) {
        self.request = request
        self.data = data
        self.error = error
    }
}

extension Response: CustomStringConvertible {
    public var description: String {
        return "request: \(String(describing: request))\n"
            + "   data: \(String(describing: data))\n"
            + "  error: \(String(describing: error))\n"
    }
}

// MARK: - Service Error

/// Service Error
///
/// - missProvider: "provider unregistered."
/// - missAction: "provider action unsupported."
/// - canceled: "request was canceled."
/// - timeout: "request timeout."
/// - invalid: "invalid request."
public enum ServiceError: Error {
    case missProvider, missAction, canceled, timeout, invalid
}

extension ServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missProvider:
            return "provider unregistered."
        case .missAction:
            return "provider action unsupported."
        case .canceled:
            return "request was canceled."
        case .timeout:
            return "request timeout."
        case .invalid:
            return "invalid request."
        }
    }
}

// MARK: - Service

/// Service
open class Service {
    fileprivate static let shared: Service = Service()

    private static let specificKey = DispatchSpecificKey<String>()
    private static let specificVal = "com.valo.appbus.service.queue"
    private static let queue: DispatchQueue = {
        let _queue = DispatchQueue(label: Service.specificVal, qos: .default, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
        _queue.setSpecific(key: Service.specificKey, value: Service.specificVal)
        return _queue
    }()

    /// providers
    private var providers: [String: Provider.Type] = [:]
}

extension Service {
    /// register provider
    fileprivate func register<T: Provider>(_ provider: T.Type) -> Bool {
        let name = provider.name
        guard !providers.keys.contains(name) else {
            return false
        }
        providers[name] = provider
        return true
    }

    /// deregister provider
    fileprivate func deregister(_ provider: String) {
        providers.removeValue(forKey: provider)
    }
}

extension Service {
    /// open url
    fileprivate func open(_ url: URL) -> Response {
        if let request = url.serviceRequest {
            return execute(request)
        }
        return Response(nil, data: nil, error: ServiceError.invalid)
    }

    /// open url
    fileprivate func open(_ urlString: String) -> Response {
        let url = URL(string: urlString)
        guard url != nil else {
            return Response(nil, data: nil, error: ServiceError.invalid)
        }
        return open(url!)
    }

    /// execute request
    fileprivate func execute(_ request: Request) -> Response {
        let provider = providers[request.provider]
        guard provider != nil else {
            return Response(request, data: nil, error: ServiceError.missProvider)
        }
        guard provider!.actions.contains(request.action) else {
            return Response(request, data: nil, error: ServiceError.missAction)
        }
        return provider!.execute(request)
    }

    /// cancel request
    fileprivate func cancel(_ request: Request) -> Response {
        return Response(request, data: nil, error: ServiceError.canceled)
    }

    /// sync
    fileprivate func sync(_ request: Request) -> Response {
        if DispatchQueue.getSpecific(key: Service.specificKey) == Service.specificVal {
            return execute(request)
        }

        var response: Response?
        Service.queue.sync {
            response = execute(request)
        }
        return response!
    }

    fileprivate func async(_ request: Request, completion: @escaping (Response) -> Void) {
        var response: Response?
        let workItem = DispatchWorkItem {
            response = response ?? Response(request, data: nil, error: ServiceError.invalid)
            completion(response!)
        }
        let cancelItem = DispatchWorkItem {
            workItem.cancel()
            let provider = self.providers[request.provider]
            provider?.cancel(request)
            let response = Response(request, data: nil, error: ServiceError.timeout)
            completion(response)
        }

        Service.queue.async {
            response = self.execute(request)
            cancelItem.cancel()
            workItem.perform()
        }
        let deadline = DispatchTime.now() + request.timeout
        Service.queue.asyncAfter(deadline: deadline, execute: cancelItem)
    }
}

// MARK: - Public

extension Service {
    /// register provider
    @discardableResult
    class func register<T: Provider>(_ provider: T.Type) -> Bool {
        return Service.shared.register(provider)
    }

    /// deregister provider
    class func deregister(_ provider: String) {
        Service.shared.deregister(provider)
    }

    /// open url
    ///
    /// - Parameters:
    ///   - url: url as follows
    ///     - `app://provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
    ///     - `app://www.xxx.com/provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
    ///     - `app://192.168.11.2/provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`
    ///   - completion: handler
    /// - Returns: success or not
    @discardableResult
    class func open(_ url: URL) -> Response {
        return shared.open(url)
    }

    /// open url
    ///
    /// - Parameters:
    ///   - url: url as follows
    ///     - `app://provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
    ///     - `app://www.xxx.com/provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
    ///     - `app://192.168.11.2/provider/action/sub1path/sub2path?key1=val1&key2=val2 ...`
    ///   - completion: handler
    /// - Returns: success or not
    @discardableResult
    class func open(_ urlString: String) -> Response {
        return shared.open(urlString)
    }

    /// execute request
    class func sync(_ request: Request) -> Response {
        return shared.sync(request)
    }

    /// execute request
    class func async(_ request: Request, completion: @escaping (Response) -> Void) {
        shared.async(request, completion: completion)
    }

    /// cancel request
    class func cancel(_ request: Request) -> Response {
        return shared.cancel(request)
    }
}
