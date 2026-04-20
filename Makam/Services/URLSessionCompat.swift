import Foundation

// Async URLSession methods were introduced in iOS 15. These extensions backport
// them to iOS 13/14 using withCheckedThrowingContinuation (available via the
// Swift concurrency back-deployment library shipped with Xcode 13.2+).

extension URLSession {
    func compatData(from url: URL) async throws -> (Data, URLResponse) {
        if #available(iOS 15, *) {
            return try await data(from: url)
        }
        return try await withCheckedThrowingContinuation { continuation in
            dataTask(with: url) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }.resume()
        }
    }

    func compatData(for request: URLRequest) async throws -> (Data, URLResponse) {
        if #available(iOS 15, *) {
            return try await data(for: request)
        }
        return try await withCheckedThrowingContinuation { continuation in
            dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }.resume()
        }
    }
}
