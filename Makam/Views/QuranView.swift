import SwiftUI
import AVFoundation

// MARK: - QuranView

struct QuranView: View {
    @StateObject private var vm = QuranViewModel()
    @State private var showChapterPicker  = false
    @State private var showReciterPicker  = false

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()

            if vm.isLoadingChapters {
                loadingView(label: "Quran")
            } else if let err = vm.errorMessage, vm.chapters.isEmpty {
                errorView(message: err)
            } else {
                mainContent
            }
        }
        .task { await vm.loadInitialData() }
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
            if vm.hasAudio {
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
                    Text(chapter.nameSimple)
                        .font(.system(size: 12))
                        .foregroundStyle(Makam.sand.opacity(0.7))
                }
            }

            Spacer()

            Button {
                showChapterPicker = true
            } label: {
                HStack(spacing: 6) {
                    if let chapter = vm.selectedChapter {
                        Text(chapter.nameArabic)
                            .font(.system(size: 14, weight: .medium))
                    } else {
                        Text("Select Surah")
                            .font(.system(size: 13))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
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
                loadingView(label: vm.selectedChapter?.nameSimple ?? "")
            } else if vm.verses.isEmpty && vm.selectedChapter != nil {
                emptyVersesView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(vm.verses.enumerated()), id: \.element.id) { idx, verse in
                                VerseRow(
                                    verse: verse,
                                    index: idx,
                                    isActive: vm.isPlaying && vm.currentVerseIndex == idx,
                                    hasAudio: vm.audioFiles[verse.verseKey] != nil
                                ) {
                                    if vm.currentVerseIndex == idx && vm.isPlaying {
                                        vm.togglePlayPause()
                                    } else {
                                        vm.playVerse(at: idx)
                                    }
                                }
                                .id(verse.id)
                            }

                            Color.clear.frame(height: vm.hasAudio ? 96 : 24)
                        }
                    }
                    .onChange(of: vm.currentVerseIndex) { _, idx in
                        guard idx < vm.verses.count else { return }
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(vm.verses[idx].id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    // MARK: Loading / Empty / Error

    private func loadingView(label: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Makam.gold)
                .scaleEffect(1.3)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Makam.sand.opacity(0.6))
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

// MARK: - Verse Row

private struct VerseRow: View {
    let verse: QuranVerse
    let index: Int
    let isActive: Bool
    let hasAudio: Bool
    let onAudioTap: () -> Void

    var translationText: String? {
        verse.translations?.first.map { stripHTMLTags($0.text) }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Verse number badge + Arabic text
            HStack(alignment: .top, spacing: 10) {
                if hasAudio {
                    Button(action: onAudioTap) {
                        ZStack {
                            Circle()
                                .fill(isActive ? Makam.gold : Makam.goldDim)
                                .frame(width: 32, height: 32)
                            Image(systemName: isActive ? "pause.fill" : "play.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(isActive ? Makam.bg : Makam.gold)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    verseNumberBadge
                }

                Spacer()
            }

            // Arabic verse
            Text(verse.textUthmani)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(isActive ? Makam.gold : Makam.sand)
                .multilineTextAlignment(.trailing)
                .lineSpacing(10)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)

            // Translation
            if let translation = translationText {
                Text(translation)
                    .font(.system(size: 13))
                    .foregroundStyle(Makam.sand.opacity(0.65))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
                .background(Makam.sand.opacity(0.12))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(isActive ? Makam.goldDim.opacity(0.5) : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private var verseNumberBadge: some View {
        ZStack {
            Circle()
                .stroke(Makam.gold.opacity(0.3), lineWidth: 1)
                .frame(width: 32, height: 32)
            Text("\(verse.verseNumber)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Makam.gold.opacity(0.7))
        }
    }

    private func stripHTMLTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
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

            HStack(spacing: 20) {
                // Reciter button
                Button(action: onReciterTap) {
                    Image(systemName: "person.wave.2")
                        .font(.system(size: 18))
                        .foregroundStyle(Makam.sand.opacity(0.7))
                }

                Spacer()

                // Prev
                Button { vm.playPreviousVerse() } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(vm.currentVerseIndex > 0 ? Makam.sand : Makam.sand.opacity(0.3))
                }
                .disabled(vm.currentVerseIndex == 0)

                // Play/Pause
                Button { vm.togglePlayPause() } label: {
                    ZStack {
                        Circle()
                            .fill(Makam.gold)
                            .frame(width: 48, height: 48)
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Makam.bg)
                            .offset(x: vm.isPlaying ? 0 : 2)
                    }
                }

                // Next
                Button { vm.playNextVerse() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            vm.currentVerseIndex < vm.verses.count - 1
                                ? Makam.sand : Makam.sand.opacity(0.3)
                        )
                }
                .disabled(vm.currentVerseIndex >= vm.verses.count - 1)

                Spacer()

                // Verse indicator
                if let verse = currentVerse {
                    Text("\(verse.verseNumber)/\(vm.verses.count)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Makam.sand.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
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

