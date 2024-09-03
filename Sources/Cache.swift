//
//  Cache.swift
//  SwiftLinkPreview
//
//  Created by Yehor Popovych on 1/17/17.
//  Copyright © 2017 leocardz.com. All rights reserved.
//

import Foundation

public protocol Cache {

    func slp_getCachedResponse(url: String) -> Response?

    func slp_setCachedResponse(url: String, response: Response?)
}

public class DisabledCache: Cache {

    public static let instance = DisabledCache()

    public func slp_getCachedResponse(url: String) -> Response? { return nil; }

    public func slp_setCachedResponse(url: String, response: Response?) { }
}

open class InMemoryCache: Cache {
    private var cache = Dictionary<String, (response: Response, date: Date)>()
    private let invalidationTimeout: TimeInterval
    private let cleanupTimer: DispatchSource?

    //High priority queue for quick responses
    private static let cacheQueue = DispatchQueue(label: "SwiftLinkPreviewInMemoryCacheQueue", qos: .userInitiated, target: DispatchQueue.global(qos: .userInitiated))

    public init(invalidationTimeout: TimeInterval = 300.0, cleanupInterval: TimeInterval = 10.0) {
        self.invalidationTimeout = invalidationTimeout

        self.cleanupTimer = DispatchSource.makeTimerSource(queue: type(of: self).cacheQueue) as? DispatchSource
        self.cleanupTimer?.schedule(deadline: .now() + cleanupInterval, repeating: cleanupInterval)

        self.cleanupTimer?.setEventHandler { [weak self] in
            guard let sself = self else {return}
            sself.cleanup()
        }

        self.cleanupTimer?.resume()
    }

    open func cleanup() {
        type(of: self).cacheQueue.async {
            for (url, data) in self.cache {
                if data.date.timeIntervalSinceNow >= self.invalidationTimeout {
                    self.cache[url] = nil
                }
            }
        }
    }

    open func slp_getCachedResponse(url: String) -> Response? {
        return type(of: self).cacheQueue.sync {
            guard let response = cache[url] else { return nil }

            if response.date.timeIntervalSinceNow >= invalidationTimeout {
                slp_setCachedResponse(url: url, response: nil)
                return nil
            }
            return response.response
        }
    }

    open func slp_setCachedResponse(url: String, response: Response?) {
        type(of: self).cacheQueue.sync {
            if let response = response {
                cache[url] = (response, Date())
            } else {
                cache[url] = nil
            }
        }
    }

    deinit {
        self.cleanupTimer?.cancel()
    }
}

open class OnDiskCache: Cache {
    private let fileURL: URL
    private let invalidationTimeout: TimeInterval
    private var cache: [String: CacheEntry] = [:]
    private let queue = DispatchQueue(label: "OnDiskCacheQueue", qos: .userInitiated)

    public init(fileURL: URL, invalidationTimeout: TimeInterval = 300.0) {
        self.fileURL = fileURL
        self.invalidationTimeout = invalidationTimeout
        loadCache()
    }

    open func cleanup() {
        queue.async {
            let now = Date()
            let originalCount = self.cache.count
            self.cache = self.cache.filter { _, entry in
                now.timeIntervalSince(entry.date) < self.invalidationTimeout
            }
            if self.cache.count < originalCount {
                self.saveCache() // Save only if items were removed
            }
        }
    }
    
    open func slp_getCachedResponse(url: String) -> Response? {
        return queue.sync {
            guard let entry = cache[url] else { return nil }
            if Date().timeIntervalSince(entry.date) >= invalidationTimeout {
                slp_setCachedResponse(url: url, response: nil)
                return nil
            }
            return entry.response
        }
    }

    open func slp_setCachedResponse(url: String, response: Response?) {
        queue.sync {
            if let response = response {
                cache[url] = CacheEntry(response: response, date: Date())
            } else {
                cache.removeValue(forKey: url)
            }
            saveCache()
        }
    }

    // MARK: - Private methods

    private func loadCache() {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let loadedCache = try? JSONDecoder().decode([String: CacheEntry].self, from: data) else {
                return
            }
            cache = loadedCache
            cleanup() // Perform cleanup after loading
        }
    }

    private func saveCache() {
        queue.async {
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(self.cache) else { return }
            try? data.write(to: self.fileURL, options: .atomicWrite)
        }
    }

    private struct CacheEntry: Codable {
        let response: Response
        let date: Date
    }
}