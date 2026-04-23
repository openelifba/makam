import Foundation

// MARK: - OAuth Token

struct QuranToken: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn   = "expires_in"
    }
}

// MARK: - Chapter

struct QuranChapterList: Decodable {
    let chapters: [QuranChapter]
}

struct QuranChapter: Decodable, Identifiable {
    let id: Int
    let nameSimple: String
    let nameArabic: String
    let versesCount: Int
    let revelationPlace: String
    let translatedName: QuranTranslatedName

    enum CodingKeys: String, CodingKey {
        case id
        case nameSimple      = "name_simple"
        case nameArabic      = "name_arabic"
        case versesCount     = "verses_count"
        case revelationPlace = "revelation_place"
        case translatedName  = "translated_name"
    }
}

struct QuranTranslatedName: Decodable {
    let name: String
}

// MARK: - Verse

struct QuranVerseList: Decodable {
    let verses: [QuranVerse]
    let pagination: QuranPagination
}

struct QuranVerse: Decodable, Identifiable {
    let id: Int
    let verseNumber: Int
    let verseKey: String
    let textUthmani: String
    let translations: [QuranTranslation]?

    enum CodingKeys: String, CodingKey {
        case id
        case verseNumber = "verse_number"
        case verseKey    = "verse_key"
        case textUthmani = "text_uthmani"
        case translations
    }
}

struct QuranTranslation: Decodable {
    let text: String
}

struct QuranPagination: Decodable {
    let perPage: Int
    let currentPage: Int
    let nextPage: Int?
    let totalPages: Int
    let totalRecords: Int

    enum CodingKeys: String, CodingKey {
        case perPage      = "per_page"
        case currentPage  = "current_page"
        case nextPage     = "next_page"
        case totalPages   = "total_pages"
        case totalRecords = "total_records"
    }
}

// MARK: - Recitation

struct QuranRecitationList: Decodable {
    let recitations: [QuranRecitation]
}

struct QuranRecitation: Decodable, Identifiable, Equatable {
    let id: Int
    let reciterNameEng: String
    let styleName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case reciterNameEng = "reciter_name_eng"
        case styleName      = "style_name"
    }

    var displayName: String {
        guard let style = styleName, !style.isEmpty else { return reciterNameEng }
        return "\(reciterNameEng) – \(style)"
    }
}

// MARK: - Audio Files

struct QuranAudioFiles: Decodable {
    let audioFiles: [QuranAudioFile]

    enum CodingKeys: String, CodingKey {
        case audioFiles = "audio_files"
    }
}

struct QuranAudioFile: Decodable {
    let verseKey: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case verseKey = "verse_key"
        case url
    }
}
