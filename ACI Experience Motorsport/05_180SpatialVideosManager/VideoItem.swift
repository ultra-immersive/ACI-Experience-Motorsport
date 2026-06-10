//
//  VideoManager180video.swift
//
//  Created by Jacques André on 10/10/25.
//

import AVFoundation
import RealityKit
import Combine


// MARK: - Supporting Types

/// Represents a video asset with playback configuration.
///
/// Contains video file information, display metadata, and playback behavior settings
/// like auto-play, looping, and start time offset.
struct VideoItem: Identifiable, Equatable {
    let id: UUID = UUID()
    let resourceName: String
    let fileExtension: String
    let title: String
    let duration: TimeInterval?
    let autoPlay: Bool
    let loop: Bool
    let startTime: TimeInterval?

    var url: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
    }
    
    init(
        resourceName: String,
        fileExtension: String = "mov",
        title: String = "",
        duration: TimeInterval? = nil,
        autoPlay: Bool = false,
        loop: Bool = false,
        startTime: TimeInterval? = nil
    ) {
        self.resourceName = resourceName
        self.fileExtension = fileExtension
        self.title = title
        self.duration = duration
        self.autoPlay = autoPlay
        self.loop = loop
        self.startTime = startTime
    }
}

