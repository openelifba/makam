import Foundation
import AVFoundation
import Combine

// MARK: - QuranViewModel

@MainActor
final class QuranViewModel: ObservableObject {

    // MARK: Data

    @Published private(set) var chapters: [QuranChapter] = []
    @Published private(set) var verses: [QuranVerse] = []
    @Published private(set) var recitations: [QuranRecitation] = []
    @Published private(set) var audioFiles: [String: String] = [:]   // verseKey → url

    // MARK: Selection

    @Published var selectedChapter: QuranChapter?
    @Published var selectedRecitation: QuranRecitation?

    // MARK: UI state

    @Published private(set) var isLoadingChapters = false
    @Published private(set) var isLoadingVerses   = false
    @Published private(set) var isLoadingAudio    = false
    @Published private(set) var errorMessage: String?

    // MARK: Player state

    @Published private(set) var isPlaying         = false
    @Published private(set) var currentVerseIndex = 0
    @Published private(set) var playerState: PlayerState = .idle

    enum PlayerState { case idle, loading, playing, paused, error }

    // MARK: Private

    private var player: AVPlayer?
    private var playerObserver: NSObjectProtocol?
    private var timeObserver: Any?

    // MARK: - Init / Load

    func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadChapters() }
            group.addTask { await self.loadRecitations() }
        }
        if selectedChapter == nil, let first = chapters.first {
            await selectChapter(first)
        }
    }

    private func loadChapters() async {
        isLoadingChapters = true
        errorMessage = nil
        do {
            chapters = try await QuranService.shared.fetchChapters()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingChapters = false
    }

    private func loadRecitations() async {
        do {
            recitations = try await QuranService.shared.fetchRecitations()
            if selectedRecitation == nil {
                selectedRecitation = recitations.first(where: { $0.id == QuranService.defaultRecitationId })
                    ?? recitations.first
            }
        } catch {
            // Recitation list is non-critical; swallow silently
        }
    }

    // MARK: - Chapter selection

    func selectChapter(_ chapter: QuranChapter) async {
        stopPlayback()
        selectedChapter = chapter
        currentVerseIndex = 0
        audioFiles = [:]
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadVerses(for: chapter) }
            group.addTask { await self.loadAudio(for: chapter) }
        }
    }

    private func loadVerses(for chapter: QuranChapter) async {
        isLoadingVerses = true
        do {
            verses = try await QuranService.shared.fetchVerses(chapterId: chapter.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingVerses = false
    }

    // MARK: - Recitation selection

    func selectRecitation(_ recitation: QuranRecitation) async {
        guard recitation != selectedRecitation else { return }
        stopPlayback()
        selectedRecitation = recitation
        audioFiles = [:]
        if let chapter = selectedChapter {
            await loadAudio(for: chapter)
        }
    }

    private func loadAudio(for chapter: QuranChapter) async {
        guard let recitation = selectedRecitation else { return }
        isLoadingAudio = true
        do {
            let files = try await QuranService.shared.fetchAudioFiles(
                recitationId: recitation.id,
                chapterId: chapter.id
            )
            var map: [String: String] = [:]
            for file in files { map[file.verseKey] = file.url }
            audioFiles = map
        } catch {
            // Audio is non-critical; player just won't show
        }
        isLoadingAudio = false
    }

    // MARK: - Playback

    func playVerse(at index: Int) {
        guard index < verses.count else { return }
        let verse = verses[index]
        guard let url = audioURL(for: verse) else { return }

        currentVerseIndex = index
        stopPlayback()

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        if player == nil { player = AVPlayer() }
        player?.replaceCurrentItem(with: item)
        player?.play()
        isPlaying = true
        playerState = .playing

        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceToNextVerse()
            }
        }
    }

    func togglePlayPause() {
        guard !verses.isEmpty else { return }
        if isPlaying {
            player?.pause()
            isPlaying = false
            playerState = .paused
        } else if playerState == .paused {
            player?.play()
            isPlaying = true
            playerState = .playing
        } else {
            // Start from currentVerseIndex
            playVerse(at: currentVerseIndex)
        }
    }

    func playPreviousVerse() {
        let target = max(0, currentVerseIndex - 1)
        playVerse(at: target)
    }

    func playNextVerse() {
        advanceToNextVerse()
    }

    private func advanceToNextVerse() {
        let next = currentVerseIndex + 1
        if next < verses.count {
            playVerse(at: next)
        } else {
            stopPlayback()
            currentVerseIndex = 0
        }
    }

    func stopPlayback() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        isPlaying = false
        playerState = .idle
        if let obs = playerObserver {
            NotificationCenter.default.removeObserver(obs)
            playerObserver = nil
        }
    }

    // MARK: - Helpers

    var hasAudio: Bool { !audioFiles.isEmpty }

    func audioURL(for verse: QuranVerse) -> URL? {
        guard let raw = audioFiles[verse.verseKey] else { return nil }
        // The API may return a relative path; prefix with the Quran CDN if needed.
        if raw.hasPrefix("http") { return URL(string: raw) }
        return URL(string: "https://verses.quran.com/" + raw)
    }
}
