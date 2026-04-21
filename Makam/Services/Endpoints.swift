// MARK: - Endpoints.swift
// Central place for all network constants.

import Foundation

enum Endpoints {
    static let baseURL  = "https://gateway.dev.wordiam.com"
    static let auth     = "\(baseURL)/auth/api"
    static let makam    = "\(baseURL)/makam/api"

    static let connectTimeoutSeconds: TimeInterval = 30
    static let receiveTimeoutSeconds: TimeInterval = 15
}
