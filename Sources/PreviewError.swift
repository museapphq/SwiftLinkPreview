//
//  PreviewError.swift
//  SwiftLinkPreview
//
//  Created by Leonardo Cardoso on 09/06/2016.
//  Copyright © 2016 leocardz.com. All rights reserved.
//
import Foundation
import UniformTypeIdentifiers

public enum PreviewError: Error, CustomStringConvertible {
    case noURLHasBeenFound(String?)
    case invalidURL(String?)
    case parseError(String?)
    case nonHttpResponse
    case failedDownload(_ error: Error)
    case unsupportedContentType(_ type: String)

    public var description: String {
        switch(self) {
        case .noURLHasBeenFound(let error):
            return NSLocalizedString("No URL has been found. \(reason(error))", comment: String())
        case .invalidURL(let error):
            return NSLocalizedString("This data is not valid URL. \(reason(error)).", comment: String())
        case .failedDownload(let error):
            return NSLocalizedString("Failed to fetch contents of URL. \(reason(error.localizedDescription)).", comment: String())
        case .parseError(let error):
            return NSLocalizedString("An error occurred when parsing the HTML. \(reason(error)).", comment: String())
        case .unsupportedContentType(let type):
            return NSLocalizedString("Unsupported content type: \(type)", comment: String())
        case .nonHttpResponse:
            return NSLocalizedString("Received invalid HTTP response", comment: String())
        }
    }

    public var localizedDescription: String {
        return description
    }

    private func reason(_ error: String?) -> String {
        return "Reason: \(error ?? String())"
    }

}
