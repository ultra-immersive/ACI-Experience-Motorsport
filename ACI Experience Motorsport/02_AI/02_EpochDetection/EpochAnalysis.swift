//
//  EpochAnalysis.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 14/11/25.
//

import FoundationModels
import SwiftUI

/// Structured result from epoch detection AI analysis.
///
/// Uses @Generable enums for `epoch` and `confidence` so constrained decoding
/// at the token level guarantees only valid values — no string matching needed.
/// Property order is reasoning → epoch → confidence (reasoning-first forces
/// the model to analyze before classifying).
@Generable(description: "Classification of a user message into an Italian motorsport epoch")
struct EpochAnalysis: Codable {
    
    // MARK: - Constrained Enums
    
    @Generable
    enum DetectedEpoch: String, Codable {
        case laCorsaComeSfida = "la_corsa_come_sfida"
        case tecnicaPassioneGenio = "tecnica_passione_genio"
        case laFormazionePiloti = "la_formazione_piloti"
        
        /// Maps the AI-detected epoch to the app's Epoch enum.
        var toAppEpoch: Epoch {
            switch self {
            case .laCorsaComeSfida: return .laCorsaComeSfida
            case .tecnicaPassioneGenio: return .tecnicaPassioneGenio
            case .laFormazionePiloti: return .laFormazionePiloti
            }
        }
    }
    
    @Generable
    enum ConfidenceLevel: String, Codable {
        case high
        case medium
        case low
    }
    
    // MARK: - Properties (order matters for generation quality)
    
    /// Generated FIRST — forces the model to reason before committing to an epoch.
    @Guide(description: "Brief analysis (max 15 words): identify the keyword, car, driver, decade or theme from the user message that indicates the epoch.")
    var reasoning: String
    
    /// Generated SECOND — after reasoning tokens are in context.
    var epoch: DetectedEpoch
    
    /// Generated LAST — confidence informed by both reasoning and epoch choice.
    var confidence: ConfidenceLevel
    
    // MARK: - Convenience Accessors
    
    var isHighConfidence: Bool { confidence == .high }
    var isMediumConfidence: Bool { confidence == .medium }
    var isLowConfidence: Bool { confidence == .low }
}
