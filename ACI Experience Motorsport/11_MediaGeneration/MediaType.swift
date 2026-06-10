//
//  MediaTypes.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 18/12/25.
//

import Foundation

// MARK: - Video Types

/// Categorizes videos by their role in the experience flow.
enum VideoCategory {
    case introductory
    case standard
    case nextModuleIntro
}

/// Configures how a video panel animates when playback starts and ends.
struct AnimationConfig {
    let panelAnimationName: String
    let useSpatialTransition: Bool
    let delayBeforeAnimation: TimeInterval
    let mediaShouldMoveForward: Bool
    let mediaShouldMoveBackward: Bool

    init(
        panelAnimationName: String,
        useSpatialTransition: Bool = false,
        delayBeforeAnimation: TimeInterval = 3.0,
        mediaShouldMoveForward: Bool = true,
        mediaShouldMoveBackward: Bool = true
    ) {
        self.panelAnimationName = panelAnimationName
        self.useSpatialTransition = useSpatialTransition
        self.delayBeforeAnimation = delayBeforeAnimation
        self.mediaShouldMoveForward = mediaShouldMoveForward
        self.mediaShouldMoveBackward = mediaShouldMoveBackward
    }
}
