//
//  StyleManager.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 16/10/25.
//

import SwiftUI
import Combine

/// Manages immersive space styling and visual effects for the experience environment.
///
/// Controls the immersion style (mixed or full) and surrounding visual effects like environment color
/// multiplication, providing centralized state for environment appearance throughout the app.
/// Supports dynamic style switching and effect transitions during the experience.
class StyleManager: ObservableObject {
    
    /// Immersion style options for the experience environment.
    ///
    /// Defines whether the experience uses mixed reality (passthrough visible) or
    /// full immersion (complete virtual environment).
    enum StyleType: String, CaseIterable {
        case mixed = "mixed"
        case full = "full"
        
        var immersionStyle: ImmersionStyle {
            switch self {
            case .mixed:
                return .mixed
            case .full:
                return .full
            }
        }
    }
    
    @Published private var _currentStyleType: StyleType = .mixed
    
    @Published var currentStyle: ImmersionStyle = .mixed
    
    @Published var currentSourroundingEffect: SurroundingsEffect =
        .colorMultiply(Color(red: 1, green: 1, blue: 1))
    
    var currentStyleType: StyleType {
        return _currentStyleType
    }
    
    // MARK: - Style Control
    
    /// Sets the immersion style to the specified type.
    ///
    /// Updates both the internal style type tracking and the published immersion style
    /// that SwiftUI observes for environment changes.
    func setStyle(_ styleType: StyleType) {
        _currentStyleType = styleType
        currentStyle = styleType.immersionStyle
    }
    
    /// Toggles between mixed and full immersion styles.
    ///
    /// Switches from the current style to the opposite style, useful for user-controlled
    /// environment adjustments during the experience.
    func toggleStyle() {
        let newStyleType: StyleType = _currentStyleType == .mixed ? .full : .mixed
        setStyle(newStyleType)
    }
}
