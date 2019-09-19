//
//  Bus.swift
//  AppBus
//
//  Created by Valo on 2019/9/11.
//

import Foundation

extension Bus {
    public struct Event: Hashable, Equatable, RawRepresentable {
        public var rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

extension Bus.Event {
    public static let `default` = Bus.Event("default")
}

extension Bus {
    public typealias Handler = (Event, Any?) -> Void

    fileprivate struct Box: Hashable {
        fileprivate var handler: Handler
        fileprivate var queue: DispatchQueue

        init(with handler: @escaping Handler, queue: DispatchQueue = .main) {
            self.handler = handler
            self.queue = queue
        }

        init?(with target: AnyObject, action: Selector, queue: DispatchQueue = .main) {
            guard target.responds(to: action) else { return nil }
            let handler: Handler = { e, o in
                _ = target.perform(action, with: e, with: o)
            }
            self.handler = handler
            self.queue = queue
        }

        static func == (lhs: Box, rhs: Box) -> Bool {
            return lhs.hashValue == rhs.hashValue
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(String(describing: handler))
        }
    }
}

public final class Bus {
    private static var boxes = [Event: Set<Box>]()
    private static let lock = DispatchSemaphore(value: 0)

    // MARK: register

    private static func register(event: Event, box: Box) {
        lock.wait()
        var set = boxes[event]
        if set == nil {
            set = Set<Box>()
            boxes[event] = set!
        }
        set!.insert(box)
        lock.signal()
    }

    public static func register(on queue: DispatchQueue = .main, event: Event, handler: @escaping Handler) {
        register(event: event, box: Box(with: handler, queue: queue))
    }

    public static func register(on queue: DispatchQueue = .main, event: Event, target: AnyObject, action: Selector) {
        guard let box = Box(with: target, action: action, queue: queue) else { return }
        register(event: event, box: box)
    }

    // MARK: deregister

    private static func deregister(event: Event, box: Box) {
        lock.wait()
        guard var set = boxes[event] else { return }
        set.remove(box)
        lock.signal()
    }

    private static func deregister(box: Box) {
        lock.wait()
        for event in boxes.keys {
            var set = boxes[event]
            set?.remove(box)
        }
        lock.signal()
    }

    public static func deregister(event: Event) {
        lock.wait()
        boxes.removeValue(forKey: event)
        lock.signal()
    }

    public static func deregister(event: Event, handler: @escaping Handler) {
        deregister(event: event, box: Box(with: handler))
    }

    public static func deregister(event: Event, target: AnyObject, action: Selector) {
        guard let box = Box(with: target, action: action) else { return }
        deregister(event: event, box: box)
    }

    public static func deregister(handler: @escaping Handler) {
        deregister(box: Box(with: handler))
    }

    public static func deregister(target: AnyObject, action: Selector) {
        guard let box = Box(with: target, action: action) else { return }
        deregister(box: box)
    }

    // Post

    public static func post(event: Event, object: Any? = nil) {
        guard let set = boxes[event] else { return }
        for box in set {
            box.queue.async {
                box.handler(event, object)
            }
        }
    }

    public static func post(on queue: DispatchQueue, event: Event, object: Any? = nil) {
        guard let set = boxes[event] else { return }
        for box in set {
            queue.async {
                box.handler(event, object)
            }
        }
    }
}
