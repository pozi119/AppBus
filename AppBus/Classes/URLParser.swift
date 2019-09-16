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
        guard let appschemes = array else {
            return _schemes
        }

        for dic in appschemes {
            let sub = dic["CFBundleURLSchemes"] as? [String] ?? []
            _schemes.append(contentsOf: sub)
        }

        return _schemes.map { $0.lowercased() }
    }()

    func isHost(_ host: String) -> Bool {
        return host.range(of: hostEx, options: .regularExpression) != nil
    }

    func parse(_ url: URL) -> (hostAndPaths: [String], parameters: [String: String]) {
        let nilValue: (hostAndPaths: [String], parameters: [String: String]) = ([], [:])
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nilValue }
        guard components.scheme != nil else { return nilValue }
        guard URLParser.shared.schemes.contains(components.scheme!.lowercased()) else { return nilValue }

        var array = components.path.split(separator: "/").map { String($0) }
        if let host = components.host, URLParser.shared.isHost(host) { array.insert(host, at: 0) }

        var parameters: [String: String] = [:]
        components.queryItems?.forEach { parameters[$0.name] = $0.value }

        return (array, parameters)
    }
}

extension URL {
    /// parse url to (path, [key : value])
    var routerParameters: (path: String, parameters: [String: String])? {
        let (array, parameters) = URLParser.shared.parse(self)
        guard array.count > 0 else { return nil }
        let path = array.joined(separator: "/")
        return (path, parameters)
    }

    /// parse url to Service Request
    var serviceRequest: Request? {
        var (array, parameters) = URLParser.shared.parse(self)
        guard array.count >= 2 else { return nil }

        let request: Request = Request()
        request.provider = array[0]
        request.action = array[1]
        array.removeFirst(2)
        request.path = array.joined(separator: "/")
        request.parameters = parameters

        return request
    }
}
