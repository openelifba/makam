import Foundation
import Statsig

enum Analytics {
    static func logEvent(_ name: String, value: String? = nil, metadata: [String: String]? = nil) {
        if let value {
            Statsig.logEvent(name, value: value, metadata: metadata)
        } else {
            Statsig.logEvent(name, metadata: metadata)
        }
    }
}
