import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias PlatformFont = NSFont
private typealias PlatformColor = NSColor
#endif

// MARK: - QuranView

struct QuranView: View {
    @StateObject private var vm = QuranViewModel()
    @StateObject private var auth = QuranAuthService.shared
    @State private var showChapterPicker  = false
    @State private var showReciterPicker  = false
    @State private var arabicChunks: [ArabicChunkData] = []
    @State private var arabicChunkChapterId: Int = -1

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()

            if !auth.isSignedIn {
                signInGate
            } else if vm.isLoadingChapters {
                loadingView(label: "القرآن الكريم")
            } else if let err = vm.errorMessage, vm.chapters.isEmpty {
                errorView(message: err)
            } else {
                mainContent
            }
        }
        .task { await vm.loadInitialData() }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn {
                Task { await vm.loadInitialData() }
            } else {
                vm.stopPlayback()
            }
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet(
                chapters: vm.chapters,
                selected: vm.selectedChapter
            ) { chapter in
                showChapterPicker = false
                Task { await vm.selectChapter(chapter) }
            }
        }
        .sheet(isPresented: $showReciterPicker) {
            ReciterPickerSheet(
                recitations: vm.recitations,
                selected: vm.selectedRecitation
            ) { recitation in
                showReciterPicker = false
                Task { await vm.selectRecitation(recitation) }
            }
        }
    }

    // MARK: Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            verseList
            if !vm.verses.isEmpty {
                AudioPlayerBar(vm: vm, onReciterTap: { showReciterPicker = true })
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("القرآن الكريم")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Makam.gold)
                if let chapter = vm.selectedChapter {
                    Text(chapter.translatedName.name)
                        .font(.system(size: 12))
                        .foregroundStyle(Makam.sand.opacity(0.7))
                }
            }

            Spacer()

            Menu {
                if let email = auth.session?.email {
                    Text(email)
                }
                Button(role: .destructive) {
                    auth.signOut()
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(Makam.sand.opacity(0.75))
            }

            Button {
                showChapterPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                    if let chapter = vm.selectedChapter {
                        Text(chapter.nameArabic)
                            .font(.system(size: 14, weight: .medium))
                            .environment(\.layoutDirection, .rightToLeft)
                    } else {
                        Text("اختر السورة")
                            .font(.system(size: 13))
                    }
                }
                .foregroundStyle(Makam.sand)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Makam.goldDim)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: Verse list

    private var verseList: some View {
        Group {
            if vm.isLoadingVerses {
                loadingView(label: vm.selectedChapter?.nameArabic ?? "")
            } else if vm.verses.isEmpty && vm.selectedChapter != nil {
                emptyVersesView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .trailing, spacing: 24) {
                            arabicFlow
                                .id("arabic")

                            translationFlow
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 96)
                    }
                    .onChange(of: vm.currentVerseIndex) { _, _ in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo("arabic", anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private var arabicFlow: some View {
        let active = vm.isPlaying ? vm.currentVerseIndex : -1
        return LazyVStack(alignment: .trailing, spacing: 0) {
            ForEach(arabicChunks) { chunk in
                let localActive: Int = {
                    let end = chunk.firstVerseIdx + chunk.verseRanges.count
                    if active >= chunk.firstVerseIdx, active < end {
                        return active - chunk.firstVerseIdx
                    }
                    return -1
                }()
                #if canImport(UIKit)
                RTLAttributedTextView(
                    attributed: chunk.attributed,
                    verseRanges: chunk.verseRanges,
                    activeIndex: localActive,
                    normalColor: PlatformColor(Makam.sand),
                    activeColor: PlatformColor(Makam.gold)
                )
                .frame(maxWidth: .infinity)
                #else
                Text(AttributedString(chunk.attributed))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                #endif
            }
        }
        .onAppear { rebuildArabicChunksIfNeeded() }
        .onChange(of: vm.selectedChapter?.id) { _, _ in rebuildArabicChunksIfNeeded() }
        .onChange(of: vm.verses.count) { _, _ in rebuildArabicChunksIfNeeded() }
    }

    private func rebuildArabicChunksIfNeeded() {
        guard let chapter = vm.selectedChapter, !vm.verses.isEmpty else {
            arabicChunks = []
            arabicChunkChapterId = -1
            return
        }
        if arabicChunkChapterId == chapter.id, !arabicChunks.isEmpty { return }
        arabicChunks = makeArabicChunks(verses: vm.verses)
        arabicChunkChapterId = chapter.id
    }

    /// Group verses by Madinah Mushaf page number — each chunk = one page.
    /// A long surah like Al-Baqarah spans ~48 pages; a short one like
    /// Al-Fatihah is a single page.
    private func makeArabicChunks(verses: [QuranVerse]) -> [ArabicChunkData] {
        var chunks: [ArabicChunkData] = []
        var i = 0
        var idx = 0
        while i < verses.count {
            let page = verses[i].pageNumber
            var end = i + 1
            while end < verses.count, verses[end].pageNumber == page { end += 1 }
            let slice = Array(verses[i..<end])
            let (attr, ranges) = buildChunkAttributed(verses: slice)
            chunks.append(ArabicChunkData(
                id: idx,
                firstVerseIdx: i,
                pageNumber: page,
                attributed: attr,
                verseRanges: ranges
            ))
            i = end
            idx += 1
        }
        return chunks
    }

    private func buildChunkAttributed(verses: [QuranVerse]) -> (NSMutableAttributedString, [NSRange]) {
        let result = NSMutableAttributedString()
        var ranges: [NSRange] = []

        let arabicFont = PlatformFont.systemFont(ofSize: 26, weight: .regular)
        let markerFont = PlatformFont.systemFont(ofSize: 16, weight: .semibold)
        let normalColor = PlatformColor(Makam.sand)
        let markerColor = PlatformColor(Makam.gold.opacity(0.7))

        result.append(NSAttributedString(string: "\u{2067}"))

        for verse in verses {
            let arabicText = verse.textUthmani + " "
            let startLoc = result.length
            result.append(NSAttributedString(string: arabicText, attributes: [
                .font: arabicFont,
                .foregroundColor: normalColor
            ]))
            ranges.append(NSRange(location: startLoc, length: result.length - startLoc))

            result.append(NSAttributedString(string: "\u{FD3F}\(verse.verseNumber)\u{FD3E}  ", attributes: [
                .font: markerFont,
                .foregroundColor: markerColor
            ]))
        }

        result.append(NSAttributedString(string: "\u{2069}"))

        let style = NSMutableParagraphStyle()
        style.baseWritingDirection = .rightToLeft
        style.alignment = .right
        style.lineSpacing = 14
        let fullRange = NSRange(location: 0, length: result.length)
        result.addAttribute(.paragraphStyle, value: style, range: fullRange)
        result.addAttribute(
            .writingDirection,
            value: [
                NSWritingDirection.rightToLeft.rawValue
                    | NSWritingDirectionFormatType.embedding.rawValue
            ],
            range: fullRange
        )

        return (result, ranges)
    }

    private var translationFlow: some View {
        let active = vm.isPlaying ? vm.currentVerseIndex : -1
        var combined = AttributedString()
        for (idx, verse) in vm.verses.enumerated() {
            guard let raw = verse.translations?.first?.text else { continue }
            let clean = stripHTMLTags(raw)

            var marker = AttributedString("\(verse.verseNumber). ")
            marker.foregroundColor = Makam.gold.opacity(0.7)
            marker.font = .system(size: 13, weight: .semibold, design: .monospaced)
            combined.append(marker)

            var run = AttributedString(clean + "  ")
            run.foregroundColor = idx == active ? Makam.gold : Makam.sand.opacity(0.65)
            combined.append(run)
        }
        return Text(combined)
            .font(.system(size: 14))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.2), value: active)
    }

    private func stripHTMLTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    // MARK: Sign-in gate

    private var signInGate: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "book.closed.fill")
                .font(.system(size: 54))
                .foregroundStyle(Makam.gold)

            VStack(spacing: 8) {
                Text("القرآن الكريم")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Makam.gold)
                    .environment(\.layoutDirection, .rightToLeft)

                Text("Sign in with Quran Foundation to read,\nbookmark, and track your progress.")
                    .font(.system(size: 14))
                    .foregroundStyle(Makam.sand.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task { await auth.signIn() }
            } label: {
                HStack(spacing: 8) {
                    if auth.isSigningIn {
                        ProgressView().controlSize(.small).tint(Makam.bg)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(auth.isSigningIn ? "Signing in…" : "Sign in with Quran Foundation")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Makam.bg)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Makam.gold)
                .clipShape(Capsule())
            }
            .disabled(auth.isSigningIn)

            if let err = auth.lastError {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Loading / Empty / Error

    private func loadingView(label: String) -> some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Makam.gold)
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .rightToLeft)

                if let translated = vm.selectedChapter?.translatedName.name {
                    Text(translated)
                        .font(.system(size: 11, weight: .medium))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Makam.sand.opacity(0.55))
                }
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Makam.gold.opacity(0), Makam.gold.opacity(0.6), Makam.gold.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 48, height: 1)

            QuranLoadingSpinner()
                .frame(width: 38, height: 38)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyVersesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 44))
                .foregroundStyle(Makam.gold.opacity(0.5))
            Text("No verses loaded")
                .foregroundStyle(Makam.sand.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(Makam.gold.opacity(0.7))
            Text(message)
                .font(.footnote)
                .foregroundStyle(Makam.sand.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                Task { await vm.loadInitialData() }
            }
            .buttonStyle(.bordered)
            .tint(Makam.gold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Audio Player Bar

private struct AudioPlayerBar: View {
    @ObservedObject var vm: QuranViewModel
    let onReciterTap: () -> Void

    private var currentVerse: QuranVerse? {
        guard vm.currentVerseIndex < vm.verses.count else { return nil }
        return vm.verses[vm.currentVerseIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Makam.gold.opacity(0.2))

            HStack(spacing: 0) {
                // Leading cluster: reciter + speed + repeat
                HStack(spacing: 12) {
                    Button(action: onReciterTap) {
                        Image(systemName: "person.wave.2")
                            .font(.system(size: 17))
                            .foregroundStyle(Makam.sand.opacity(0.7))
                    }

                    Menu {
                        ForEach(QuranViewModel.rateOptions, id: \.self) { rate in
                            Button {
                                vm.setPlaybackRate(rate)
                            } label: {
                                HStack {
                                    Text(Self.rateLabel(rate))
                                    if vm.playbackRate == rate {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(Self.rateLabel(vm.playbackRate))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(vm.playbackRate == 1 ? Makam.sand.opacity(0.75) : Makam.gold)
                            .frame(minWidth: 28)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(vm.playbackRate == 1 ? Makam.sand.opacity(0.25) : Makam.gold.opacity(0.5), lineWidth: 1)
                            )
                    }

                    Menu {
                        ForEach(QuranViewModel.repeatOptions, id: \.self) { n in
                            Button {
                                vm.setRepeatPerVerse(n)
                            } label: {
                                HStack {
                                    Text(n == 1 ? "Off" : "×\(n)")
                                    if vm.repeatPerVerse == n {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: vm.repeatPerVerse > 1 ? "repeat.1" : "repeat")
                                .font(.system(size: 13, weight: .semibold))
                            if vm.repeatPerVerse > 1 {
                                Text("\(vm.repeatPerVerse)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundStyle(vm.repeatPerVerse > 1 ? Makam.gold : Makam.sand.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Center cluster: prev + play + next
                HStack(spacing: 20) {
                    Button { vm.playPreviousVerse() } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(vm.currentVerseIndex > 0 ? Makam.sand : Makam.sand.opacity(0.3))
                    }
                    .disabled(vm.currentVerseIndex == 0 || vm.isLoadingAudio)

                    Button { vm.togglePlayPause() } label: {
                        ZStack {
                            Circle()
                                .fill(Makam.gold)
                                .frame(width: 48, height: 48)
                            Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Makam.bg)
                                .offset(x: vm.isPlaying ? 0 : 2)
                                .opacity(vm.isLoadingAudio ? 0.4 : 1)
                        }
                        .overlay(alignment: .topTrailing) {
                            if vm.isLoadingAudio {
                                Circle()
                                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
                                    .frame(width: 18, height: 18)
                                    .overlay {
                                        ProgressView()
                                            .controlSize(.mini)
                                            .tint(Makam.gold)
                                    }
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .disabled(vm.isLoadingAudio)

                    Button { vm.playNextVerse() } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                vm.currentVerseIndex < vm.verses.count - 1
                                    ? Makam.sand : Makam.sand.opacity(0.3)
                            )
                    }
                    .disabled(vm.currentVerseIndex >= vm.verses.count - 1 || vm.isLoadingAudio)
                }

                // Trailing cluster: verse counter
                Group {
                    if let verse = currentVerse {
                        Text("\(verse.verseNumber)/\(vm.verses.count)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Makam.sand.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        }
    }

    private static func rateLabel(_ rate: Float) -> String {
        switch rate {
        case 0.5:  return "0.5×"
        case 0.75: return "0.75×"
        case 1.0:  return "1×"
        case 1.25: return "1.25×"
        case 1.5:  return "1.5×"
        default:   return String(format: "%.2g×", rate)
        }
    }
}

// MARK: - Chapter Picker Sheet

private struct ChapterPickerSheet: View {
    let chapters: [QuranChapter]
    let selected: QuranChapter?
    let onSelect: (QuranChapter) -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [QuranChapter] {
        guard !searchText.isEmpty else { return chapters }
        let q = searchText.lowercased()
        return chapters.filter {
            $0.nameSimple.lowercased().contains(q)
            || $0.nameArabic.contains(searchText)
            || $0.translatedName.name.lowercased().contains(q)
            || "\($0.id)".contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { chapter in
                Button {
                    onSelect(chapter)
                } label: {
                    HStack {
                        // Chapter number
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Makam.goldDim)
                                .frame(width: 36, height: 36)
                            Text("\(chapter.id)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Makam.gold)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(chapter.nameSimple)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Makam.sand)
                            Text(chapter.translatedName.name)
                                .font(.system(size: 12))
                                .foregroundStyle(Makam.sand.opacity(0.55))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(chapter.nameArabic)
                                .font(.system(size: 16))
                                .foregroundStyle(Makam.gold)
                            Text("\(chapter.versesCount) ayahs")
                                .font(.system(size: 11))
                                .foregroundStyle(Makam.sand.opacity(0.45))
                        }

                        if selected?.id == chapter.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Makam.gold)
                                .padding(.leading, 6)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color(red: 0.10, green: 0.10, blue: 0.13))
            }
            .listStyle(.plain)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
            .scrollContentBackground(.hidden)
            .searchable(text: $searchText, prompt: "Search surah…")
            .navigationTitle("Select Surah")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Makam.gold)
                }
            }
            .toolbarBackground(Color(red: 0.08, green: 0.08, blue: 0.10), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.large])
    }
}

// MARK: - Reciter Picker Sheet

private struct ReciterPickerSheet: View {
    let recitations: [QuranRecitation]
    let selected: QuranRecitation?
    let onSelect: (QuranRecitation) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(recitations) { recitation in
                Button {
                    onSelect(recitation)
                } label: {
                    HStack {
                        Image(systemName: "person.wave.2")
                            .font(.system(size: 16))
                            .foregroundStyle(Makam.gold.opacity(0.8))
                            .frame(width: 28)

                        Text(recitation.displayName)
                            .font(.system(size: 14))
                            .foregroundStyle(Makam.sand)

                        Spacer()

                        if selected?.id == recitation.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Makam.gold)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color(red: 0.10, green: 0.10, blue: 0.13))
            }
            .listStyle(.plain)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
            .scrollContentBackground(.hidden)
            .navigationTitle("Select Reciter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Makam.gold)
                }
            }
            .toolbarBackground(Color(red: 0.08, green: 0.08, blue: 0.10), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Loading Spinner

private struct QuranLoadingSpinner: View {
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.72)
            .stroke(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: Makam.gold.opacity(0), location: 0),
                        .init(color: Makam.gold.opacity(0.25), location: 0.5),
                        .init(color: Makam.gold, location: 1.0)
                    ]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Arabic chunk data

private struct ArabicChunkData: Identifiable {
    let id: Int
    let firstVerseIdx: Int
    let pageNumber: Int
    let attributed: NSMutableAttributedString
    let verseRanges: [NSRange]
}

#if canImport(UIKit)
// MARK: - RTL Attributed Text View
//
// Each instance renders one chunk (~20 verses). UITextView uses
// NSLayoutManager which honors NSParagraphStyle.baseWritingDirection for
// arbitrary content lengths, unlike UILabel (single CALayer ceiling) and
// SwiftUI Text (drops paragraph style entirely).
//
// Active-verse highlight is applied directly to the text view's
// textStorage rather than rebuilding the AttributedString — incremental
// glyph re-render is O(range size), full re-layout would be O(chunk size).

private struct RTLAttributedTextView: UIViewRepresentable {
    let attributed: NSMutableAttributedString
    let verseRanges: [NSRange]
    let activeIndex: Int
    let normalColor: UIColor
    let activeColor: UIColor

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textAlignment = .right
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        tv.setContentHuggingPriority(.defaultHigh, for: .vertical)
        tv.attributedText = attributed
        context.coordinator.boundAttributed = attributed
        applyHighlight(tv: tv, context: context)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if context.coordinator.boundAttributed !== attributed {
            uiView.attributedText = attributed
            context.coordinator.boundAttributed = attributed
            context.coordinator.lastActiveIndex = nil
        }
        applyHighlight(tv: uiView, context: context)
    }

    private func applyHighlight(tv: UITextView, context: Context) {
        if context.coordinator.lastActiveIndex == activeIndex { return }
        let storage = tv.textStorage
        storage.beginEditing()
        if let prev = context.coordinator.lastActiveIndex,
           prev >= 0, prev < verseRanges.count {
            storage.addAttribute(.foregroundColor, value: normalColor, range: verseRanges[prev])
        }
        if activeIndex >= 0, activeIndex < verseRanges.count {
            storage.addAttribute(.foregroundColor, value: activeColor, range: verseRanges[activeIndex])
        }
        storage.endEditing()
        context.coordinator.lastActiveIndex = activeIndex
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var boundAttributed: NSMutableAttributedString?
        var lastActiveIndex: Int?
    }
}
#endif

