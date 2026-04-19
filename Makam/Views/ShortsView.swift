import SwiftUI
import AVKit
import AVFoundation

// MARK: - ShortsView

struct ShortsView: View {
    @StateObject private var service = JellyfinService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if service.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .accentColor(.white)
                        .scaleEffect(1.4)
                    Text("Loading…")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.subheadline)
                }
            } else if let err = service.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.7))
                    Text(err)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Retry") {
                        Task { await service.fetchItems() }
                    }
                    .borderedButtonStyleIfAvailable()
                    .accentColor(.white)
                }
            } else if service.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.6))
                    Text("No videos found")
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                ShortsFeed(items: service.items)
            }
        }
        .onAppear { Task { await service.fetchItems() } }
    }
}

// MARK: - Feed

private struct ShortsFeed: View {
    let items: [JellyfinItem]

    @State private var activeID: String?

    var body: some View {
        TabView(selection: $activeID) {
            ForEach(items) { item in
                ShortPlayerView(item: item, isActive: activeID == item.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .tag(item.id as String?)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .onAppear {
            if activeID == nil { activeID = items.first?.id }
        }
        .onChange(of: activeID) { newID in
            guard let newID, let item = items.first(where: { $0.id == newID }) else { return }
            Analytics.logEvent(
                "shorts_video_loaded",
                metadata: ["videoId": newID, "videoName": item.name]
            )
        }
    }
}

// MARK: - Single short

private struct ShortPlayerView: View {
    let item: JellyfinItem
    let isActive: Bool

    @State private var player: AVPlayer?
    @State private var isMuted = false

    var body: some View {
        ZStack {
            Color.black

            if let player {
                VideoLayerView(player: player)
                    .ignoresSafeArea()
            }

            // Bottom overlay
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        isMuted.toggle()
                        player?.isMuted = isMuted
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
                )
            }
        }
        .onAppear { setupPlayerIfNeeded() }
        .onDisappear {
            player?.pause()
            player?.seek(to: .zero)
            player = nil
        }
        .onChange(of: isActive) { active in
            if active {
                player?.play()
            } else {
                player?.pause()
                player?.seek(to: .zero)
            }
        }
    }

    private func setupPlayerIfNeeded() {
        guard player == nil else { return }
        let url = JellyfinService.streamURL(for: item.id)
        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = isMuted

        // Loop
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }

        player = avPlayer
        if isActive { avPlayer.play() }
    }
}

// MARK: - UIViewRepresentable for AVPlayerLayer

private struct VideoLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> _PlayerUIView {
        let view = _PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: _PlayerUIView, context: Context) {
        uiView.player = player
    }
}

final class _PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspect
        }
    }
}
