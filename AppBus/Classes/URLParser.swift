//
//  URLParser.swift
//  AppBus
//
//  Created by Valo on 2019/9/12.
//

import Foundation

fileprivate class URLParser {
    static let shared = URLParser()

    let hostEx = "(([a-zA-Z0-9\\.\\-]+\\.([a-zA-Z]{2,4}))" + "|"
        + "((25[0-5]|2[0-4]\\d|((1\\d{2})|([1-9]?\\d)))\\.){3}"
        + "(25[0-5]|2[0-4]\\d|((1\\d{2})|([1-9]?\\d))))"

    /// app schemes
    lazy var schemes: [String] = {
        var _schemes: [String] = ["http", "https"]

        let array = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        guard array != nil else {
            return _schemes
        }

        for dic in array! {
            let sub = dic["CFBundleURLSchemes"] as? [String] ?? []
            _schemes.append(contentsOf: sub)
        }

        return _schemes.map { $0.lowercased() }
    }()

    func isHost(_ host: String) -> Bool {
        return host.range(of: hostEx, options: .regularExpression) != nil
    }
}

extension URL {
    /// parse url to (path, [key : value])
    var routerParameters: (path: String, parameters: [String: String])? {
        let components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        guard components != nil else { return nil }
        guard components!.scheme != nil else { return nil }
        guard URLParser.shared.schemes.contains(components!.scheme!.lowercased()) else { return nil }

        var array = components!.path.split(separator: "/").map { String($0) }
        let host = components!.host
        if host != nil && URLParser.shared.isHost(host!) { array.insert(host!, at: 0) }

        guard array.count > 0 else { return nil }

        let path = array.joined(separator: "/")

        var parameters: [String: String] = [:]
        components?.queryItems?.forEach { parameters[$0.name] = $0.value }

        return (path, parameters)
    }

    /// parse url to Service Request
    var serviceRequest: Request? {
        let components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        guard components != nil else { return nil }
        guard components!.scheme != nil else { return nil }
        guard URLParser.shared.schemes.contains(components!.scheme!.lowercased()) else { return nil }

        var array = components!.path.split(separator: "/").map { String($0) }
        let host = components!.host
        if host != nil && URLParser.shared.isHost(host!) { array.insert(host!, at: 0) }

        guard array.count >= 2 else { return nil }

        let request: Request = Request()
        request.provider = array[0]
        request.action = array[1]
        array.removeFirst(2)
        request.path = array.joined(separator: "/")

        var parameters: [String: String] = [:]
        components?.queryItems?.forEach { parameters[$0.name] = $0.value }
        request.parameters = parameters

        return request
    }
}
