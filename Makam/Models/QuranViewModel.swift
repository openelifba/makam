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

    // How many times to play each verse before advancing (1 = play once).
    @Published var repeatPerVerse: Int = 1
    // 0.5…1.5; applied to AVPlayer.rate while playing.
    @Published var playbackRate: Float = 1.0

    static let repeatOptions: [Int] = [1, 2, 3, 5, 10]
    static let rateOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5]

    enum PlayerState { case idle, loading, playing, paused, error }

    // MARK: Private

    private var player: AVPlayer?
    private var playerObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var currentVersePlayCount = 0

    // MARK: - Init / Load

    func loadInitialData() async {
        // Require a signed-in Quran Foundation session before hitting the API.
        guard QuranAuthService.shared.isSignedIn else {
            chapters = []
            verses = []
            recitations = []
            return
        }
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
        await loadVerses(for: chapter)
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
        playVerse(at: index, resetRepeat: true)
    }

    private func playVerse(at index: Int, resetRepeat: Bool) {
        guard index < verses.count else { return }
        let verse = verses[index]
        guard let url = audioURL(for: verse) else { return }

        if index != currentVerseIndex || resetRepeat {
            currentVersePlayCount = 0
        }
        currentVerseIndex = index
        stopPlayback()

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        item.audioTimePitchAlgorithm = .spectral
        if player == nil { player = AVPlayer() }
        player?.replaceCurrentItem(with: item)
        player?.playImmediately(atRate: playbackRate)
        isPlaying = true
        playerState = .playing

        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleVerseEnd()
            }
        }
    }

    private func handleVerseEnd() {
        currentVersePlayCount += 1
        if currentVersePlayCount < max(repeatPerVerse, 1) {
            playVerse(at: currentVerseIndex, resetRepeat: false)
        } else {
            advanceToNextVerse()
        }
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying { player?.rate = rate }
    }

    func setRepeatPerVerse(_ count: Int) {
        repeatPerVerse = max(count, 1)
    }

    func togglePlayPause() {
        guard !verses.isEmpty else { return }
        if isPlaying {
            player?.pause()
            isPlaying = false
            playerState = .paused
            return
        }
        if playerState == .paused {
            player?.playImmediately(atRate: playbackRate)
            isPlaying = true
            playerState = .playing
            return
        }
        Task { await startPlaybackFromCurrent() }
    }

    func playPreviousVerse() {
        let target = max(0, currentVerseIndex - 1)
        Task { await jumpAndPlay(target) }
    }

    func playNextVerse() {
        let target = currentVerseIndex + 1
        guard target < verses.count else {
            stopPlayback()
            currentVerseIndex = 0
            return
        }
        Task { await jumpAndPlay(target) }
    }

    private func startPlaybackFromCurrent() async {
        await ensureAudioLoaded()
        guard !audioFiles.isEmpty else { return }
        playVerse(at: currentVerseIndex)
    }

    private func jumpAndPlay(_ index: Int) async {
        await ensureAudioLoaded()
        guard !audioFiles.isEmpty else { return }
        playVerse(at: index)
    }

    private func ensureAudioLoaded() async {
        guard audioFiles.isEmpty, let chapter = selectedChapter else { return }
        await loadAudio(for: chapter)
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

    var canPlay: Bool {
        !verses.isEmpty
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
