//
//  VR180Methods.swift
//
//  Created by Jacques André on 10/10/25.
//

import Foundation
import RealityKit
import AVFoundation

/// ImmersiveView extension for VR180 video manager setup and playback control.
///
/// Configures the video manager with callbacks for start, end, and state change events,
/// coordinates window management for video controls, handles environment transitions for
/// immersive video playback, and provides video loading with bundle resource validation.
extension ImmersiveView {
    
    // MARK: - Video Manager Setup
    
    /// Sets up the video manager with entity configuration and event callbacks.
    ///
    /// Configures video manager with player and parent entity, then sets up three key callbacks:
    /// (1) onVideoStart: Shows control window, pauses other video entities playing in ImageScreen
    /// containers, (2) onVideoEnd: Closes control window, fades out video entity, transitions
    /// environment color from black to white, sends experience completion notification,
    /// (3) onStateChange: Logs state transitions and handles ready/failed states with debug info.
    /// Essential for coordinating VR180 video playback with the rest of the experience.
    func setupVideoManager(with entity: Entity) {
        let videoManager = appModel.videoManager
        videoManager.configure(with: appModel.player, parentEntity: entity)
        
        videoManager.onVideoStart = { video in
            print("Started video: \(video.title)")
            Task {
                try? await Task.sleep(for: .seconds(6))
                showWindow(id: "ControlVideo")
            }
            
            rootEntity.enumerateHierarchy { entity, stop in
                if entity.name == "ImageScreen" {
                    for child in entity.children {
                        if child.name.starts(with: "VideoEntity"),
                           let videoComponent = child.components[VideoPlayerComponent.self] {
                            videoComponent.avPlayer?.pause()
                        }
                    }
                }
            }
        }
        
        videoManager.onVideoEnd = { video in
            Task {
                closeWindow(id:"ControlVideo")
                videoManager.videoEntity?.components.set(OpacityComponent(opacity: 1.0))
                graduallyChangeOpacity(entity: videoManager.videoEntity!, targetOpacity: 0, duration: 1.5)
                graduallyChangeColorEffect(duration: 1.0, styleManager: styleManager, startColor: [0,0,0], targetColor: [1.0,1.0,1.0], completion: {
                })
                if let generalOpacity = rootEntity.findEntity(named: "GeneralOpacity") {
                    graduallyChangeOpacity(entity: generalOpacity, targetOpacity: 1, duration: 2) {
                    }
                }
                                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        
        videoManager.onStateChange = { state in
            print("Video state changed: \(state)")
            switch state {
            case .failed(let error):
                print("Video failed: \(error)")
            case .ready:
                print("Video is ready")
                Task { @MainActor in
                    let hasVideoEntity = rootEntity.children.contains { $0.name == "SpatialVideoPlayer" }
                    print(" Video entity spawned: \(hasVideoEntity)")
                }
            case .playing:
                print(" Video is now playing")
            case .ended:
                print(" Video ended")
            default:
                break
            }
        }
    }
    
    // MARK: - Video Loading
    
    /// Loads and optionally plays a VR180 video from the bundle with validation.
    ///
    /// Validates video file existence in bundle, lists available video files if not found,
    /// creates VideoItem with title and auto-play settings, supports optional start time
    /// for seeking to specific position, and delegates to video manager for loading and
    /// playback. Used for Module D VR180 immersive video experiences.
    func loadAndPlayVideo(resourceName: String, autoPlay: Bool, title: String, startTime: TimeInterval? = nil) async {
        let resourceName = resourceName
        
        if Bundle.main.url(forResource: resourceName, withExtension: "mov") != nil {
        } else {
            print(" Video file not found: \(resourceName).mov")
            print("Available video files in bundle:")
            if let resourcePath = Bundle.main.resourcePath {
                do {
                    let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    let videos = files.filter { $0.hasSuffix(".mov") || $0.hasSuffix(".mp4") }
                    videos.forEach { print("   - \($0)") }
                } catch {
                    print("Could not list files: \(error)")
                }
            }
            return
        }
        
        let video = VideoItem(
            resourceName: resourceName,
            title: title,
            autoPlay: autoPlay,
            startTime: startTime
        )
        await appModel.videoManager.loadVideo(video)
    }
}
