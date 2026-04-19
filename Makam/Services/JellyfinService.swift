import Foundation
import AVFoundation

// MARK: - Models

struct JellyfinItem: Codable, Identifiable {
    let id: String
    let name: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
    }
}

struct JellyfinItemsResponse: Codable {
    let items: [JellyfinItem]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}

// MARK: - Service

@MainActor
final class JellyfinService: ObservableObject {

    static let baseURL = "http://10.0.0.2:8096"
    static let apiKey  = "70950ae62a254f65a072bd78730ea66a"

    @Published var items: [JellyfinItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    static func streamURL(for itemId: String) -> URL {
        URL(string: "\(baseURL)/Videos/\(itemId)/stream?api_key=\(apiKey)&Static=true&MediaSourceId=\(itemId)")!
    }

    static func thumbnailURL(for itemId: String) -> URL {
        URL(string: "\(baseURL)/Items/\(itemId)/Images/Primary?api_key=\(apiKey)&fillWidth=400&quality=80")!
    }

    func fetchItems() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let urlString = "\(Self.baseURL)/Items?IncludeItemTypes=Movie,Episode,Video&Recursive=true&api_key=\(Self.apiKey)&Fields=BasicSyncInfo&SortBy=DateCreated&SortOrder=Descending&Limit=100"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(JellyfinItemsResponse.self, from: data)
            items = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
