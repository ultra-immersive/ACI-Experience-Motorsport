//
//  VideoState180.swift
//
//  Created by Jacques André on 10/10/25.
//

import Foundation

/// Video playback state enumeration.
///
/// Represents the current state of video playback with failure information when applicable.
enum VideoState: Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case ended
    case failed(String)
}
