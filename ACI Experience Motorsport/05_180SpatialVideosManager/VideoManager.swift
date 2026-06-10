//
//  VideoManager180video.swift
//
//  Created by Jacques André on 10/10/25.
//

import AVFoundation
import RealityKit
import Combine

/// Manages spatial video playback with queue management and RealityKit integration.
///
/// Coordinates AVPlayer control, spatial video entity spawning, playback state tracking,
/// and queue-based video sequences. Provides callbacks for playback events and progress
/// updates, supporting auto-play, looping, and start-time seeking for VR180 experiences.
@MainActor
@Observable
final class VideoManager {
    private var videoEntityPosition = SIMD3<Float>(0, 1.0, -0.75)
    
    private(set) var currentVideo: VideoItem?
    private(set) var videoState: VideoState = .idle
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isBuffering = false
    
    private var videoQueue: [VideoItem] = []
    private var queueIndex: Int = 0
    
    weak var player: AVPlayer?
    var videoEntity: Entity?
    private var parentEntity: Entity?
    
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var bufferObserver: NSKeyValueObservation?
    private var didPlayToEndObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    var onVideoStart: ((VideoItem) -> Void)?
    var onVideoEnd: ((VideoItem) -> Void)?
    var onVideoProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onStateChange: ((VideoState) -> Void)?
    
    init() {
        setupNotifications()
    }
    
    deinit {
    }
    
    // MARK: - Configuration
    
    /// Configures the manager with a player and parent entity for video spawning.
    ///
    /// Sets up the AVPlayer reference and parent entity where spatial video entities
    /// will be added, then establishes playback observers.
    func configure(with player: AVPlayer, parentEntity: Entity) {
        self.player = player
        self.parentEntity = parentEntity
        setupPlayerObservers()
    }
    
    /// Registers for AVPlayer completion notifications.
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] notification in
                guard let self = self,
                      let playerItem = notification.object as? AVPlayerItem,
                      playerItem == self.player?.currentItem else { return }
                Task { @MainActor in
                    await self.handleVideoEnd()
                }
            }
            .store(in: &cancellables)
    }

    /// Sets up periodic time observer for progress tracking.
    private func setupPlayerObservers() {
        guard let player = player else { return }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.updateProgress(time: time)
            }
        }
    }

    /// Updates playback progress and invokes progress callback.
    private func updateProgress(time: CMTime) {
        guard videoState == .playing else { return }
        currentTime = time.seconds
        onVideoProgress?(currentTime, duration)
    }
    
    // MARK: - Video Loading
    
    /// Loads a video item and prepares it for playback.
    ///
    /// Creates an AVPlayerItem from the video URL, loads asset properties, sets up observers,
    /// spawns the spatial video entity if needed, seeks to start time, and auto-plays if configured.
    func loadVideo(_ video: VideoItem) async {
        currentVideo = video
        updateState(.loading)
        
        guard let url = video.url else {
            updateState(.failed("Video file not found: \(video.resourceName)"))
            return
        }
        
        do {
            let asset = AVURLAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            
            setupItemObservers(for: playerItem)
            
            player?.replaceCurrentItem(with: playerItem)
            
            let (duration, _) = try await asset.load(.duration, .tracks)
            
            self.duration = duration.seconds
            self.updateState(.ready)

            if self.videoEntity == nil {
                self.spawnVideoEntity()
            }

            if let startTime = video.startTime, startTime > 0 {
                await self.seek(to: startTime)
            }

            if video.autoPlay {
                self.play()
            }
            
        } catch {
            updateState(.failed("Failed to load video: \(error.localizedDescription)"))
        }
    }
    
    /// Establishes KVO observers for player item status and buffering state.
    private func setupItemObservers(for item: AVPlayerItem) {
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.handleStatusChange(item.status)
                }
            }
        }
        
        bufferObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isBuffering = !item.isPlaybackLikelyToKeepUp
                }
            }
        }
    }
    
    // MARK: - Playback Control
    
    /// Begins or resumes video playback.
    ///
    /// Starts the AVPlayer and invokes the video start callback if not already playing.
    func play() {
        guard videoState == .ready || videoState == .paused else { return }
        
        player?.play()
        updateState(.playing)
        
        if let video = currentVideo {
            onVideoStart?(video)
        }
    }
    
    /// Pauses video playback without resetting position.
    func pause() {
        guard videoState == .playing else { return }
        
        player?.pause()
        updateState(.paused)
    }
    
    /// Stops playback and resets to the beginning.
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        updateState(.idle)
        currentTime = 0
    }
    
    /// Seeks to a specific time position in the current video.
    func seek(to time: TimeInterval) async {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        await player?.seek(to: cmTime)
        currentTime = time
    }
    
    // MARK: - Queue Management
    
    /// Sets the video queue and loads the first video.
    ///
    /// Replaces the current queue with new videos and begins loading the first item.
    func setQueue(_ videos: [VideoItem]) {
        videoQueue = videos
        queueIndex = 0
        
        if let first = videos.first {
            Task {
                await loadVideo(first)
            }
        }
    }
    
    /// Advances to and loads the next video in the queue with wrap-around.
    func playNext() {
        guard !videoQueue.isEmpty else { return }
        
        queueIndex = (queueIndex + 1) % videoQueue.count
        let nextVideo = videoQueue[queueIndex]
        
        Task {
            await loadVideo(nextVideo)
        }
    }
    
    /// Returns to and loads the previous video in the queue with wrap-around.
    func playPrevious() {
        guard !videoQueue.isEmpty else { return }
        
        queueIndex = queueIndex > 0 ? queueIndex - 1 : videoQueue.count - 1
        let previousVideo = videoQueue[queueIndex]
        
        Task {
            await loadVideo(previousVideo)
        }
    }
    
    // MARK: - Video Entity Management

    /// Spawns a spatial video entity in the RealityKit scene.
    ///
    /// Creates a ModelEntity with VideoPlayerComponent configured for spatial stereo playback,
    /// positions it in front of the user, and adds it to the parent entity hierarchy.
    private func spawnVideoEntity() {
        guard let parentEntity = parentEntity,
              let player = player else { return }
        
        videoEntity?.removeFromParent()
        
        let modelEntity = ModelEntity()
        
        var videoPlayerComponent = VideoPlayerComponent(avPlayer: player)
        videoPlayerComponent.desiredImmersiveViewingMode = .full
        videoPlayerComponent.desiredSpatialVideoMode = .spatial
        videoPlayerComponent.desiredViewingMode = .stereo
        
        modelEntity.components.set(videoPlayerComponent)
        
        modelEntity.position = videoEntityPosition
        
        modelEntity.scale = SIMD3<Float>(1.0, 1.0, 1.0)
        
        modelEntity.name = "SpatialVideoPlayer"
        
        parentEntity.addChild(modelEntity)
        
        videoEntity = modelEntity
        
    }
    
    /// Removes the video entity from the scene hierarchy.
    func removeVideoEntity() {
        videoEntity?.removeFromParent()
        videoEntity = nil
    }
    
    // MARK: - State Management
    
    /// Updates playback state and invokes state change callback.
    private func updateState(_ newState: VideoState) {
        videoState = newState
        onStateChange?(newState)
    }
    
    /// Handles AVPlayerItem status changes.
    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            if videoState == .loading {
                updateState(.ready)
            }
        case .failed:
            updateState(.failed("Player item failed"))
        case .unknown:
            break
        @unknown default:
            break
        }
    }
    
    /// Handles video completion, triggering loop or queue advancement.
    private func handleVideoEnd() async {
        if let video = currentVideo {
            onVideoEnd?(video)
            
            if video.loop {
                play()
            } else if !videoQueue.isEmpty {
                playNext()
            } else {
                updateState(.ended)
            }
        }
    }
    
    /// Performs complete cleanup of all resources and observers.
    ///
    /// Stops playback, removes all observers and subscriptions, cleans up video entity
    /// and components, clears player references, resets state, and removes callbacks.
    func cleanup() {
        
        stop()
        
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        statusObserver?.invalidate()
        statusObserver = nil
        
        bufferObserver?.invalidate()
        bufferObserver = nil
        
        cancellables.removeAll()
        
        if let videoEntity = videoEntity {
            videoEntity.components.removeAll()
            videoEntity.removeFromParent()
            self.videoEntity = nil
        }
        
        player?.replaceCurrentItem(with: nil)
        
        player = nil
        parentEntity = nil
        currentVideo = nil
        
        videoQueue.removeAll()
        queueIndex = 0
        
        onVideoStart = nil
        onVideoEnd = nil
        onVideoProgress = nil
        onStateChange = nil
        
        videoState = .idle
        currentTime = 0
        duration = 0
        isBuffering = false
        
    }
}
