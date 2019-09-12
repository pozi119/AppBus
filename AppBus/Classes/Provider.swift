//
//  Provider.swift
//  AppBus
//
//  Created by Valo on 2019/9/11.
//

import Foundation

// MARK: - Provider

/// Provider, execute requests
public protocol Provider {
    /// provider name
    static var name: String { get }
    
    /// supported actions
    static var actions: [String] { get }
    
    /// execute a request
    static func execute(_ request: Request) -> Response
    
    /// cancel a request
    static func cancel(_ request: Request)
}
