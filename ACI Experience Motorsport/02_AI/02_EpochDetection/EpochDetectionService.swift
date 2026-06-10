//
//  EpochDetectionService.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 14/11/25.
//

import Foundation
import FoundationModels

/// Detects historical motorsport epoch from user input using FoundationModels.
///
/// Design rationale:
/// - Uses `SystemLanguageModel.default` (general purpose, best for understanding intent)
/// - NOT contentTagging (that adapter extracts tags, doesn't classify into custom categories)
/// - Provides narrative context: the model knows WHAT the user was asked, so it can
///   understand vague answers like "sorprendimi" or "la seconda"
/// - Fresh session per call to avoid conversation history contamination
/// - @Generable enums guarantee valid output via constrained decoding
@MainActor
class EpochDetectionService {
    
    // MARK: - Instructions
    
    private static let instructions = """
    You are classifying a user's response into one of three Italian motorsport epochs.
    
    CONTEXT: The user was just asked this welcome question in Italian:
    "Da dove vuoi iniziare il tuo viaggio nel Motorsport italiano?
    Dalle origini, tra Alfa Romeo e Ferrari, con piloti leggendari come Nuvolari e Ascari?
    Dall'età dei grandi rally, tra Lancia Stratos, Lancia Delta e le vittorie di Miki Biasion?
    Oppure dal presente, tra ACI Sport, la Formula 4 e la nascita delle nuove generazioni di piloti?"
    
    The three epochs are:
    
    EPOCH 1 — laCorsaComeSfida: The pioneering era (1900–1969). Early motorsport, open roads, Targa Florio, Monza, Alfa Romeo, Ferrari's debut, Nuvolari, Ascari, Novecento, Anni Sessanta, Nascita. The first choice offered. Also referred to as "la prima" or "le origini."
    
    EPOCH 2 — tecnicaPassioneGenio: The golden rally era (1970–1990). Lancia Stratos, Delta, 037, Group B, Biasion, Rally di Sanremo, iconic liveries, Made in Italy design, Anni Settanta, Anni Ottanta, Anni Novanta, Donne. The second choice offered. Also referred to as "la seconda" or "l'età d'oro."
    
    EPOCH 3 — laFormazionePiloti: The modern era (2000–future). Safety culture, Halo, driver training, Vallelunga, Formula 4, Tatuus, Formula E, eSport, simulators, new generations, Anni Duemila, Giro in pista. The third choice offered. Also referred to as "la terza" or "il presente."
    
    CLASSIFICATION GUIDANCE:
    - If the user picks a choice (first/second/third, or references content from one), classify accordingly.
    - If the user names a specific car, driver, event, or decade, classify by which epoch it belongs to.
    - If the user is vague, delegates ("scegli tu", "sorprendimi"), or just greets without choosing, classify as laFormazionePiloti with low confidence.
    - If the user wants everything ("tutto", "tutte le epoche", "il percorso completo"), classify as laFormazionePiloti with low confidence (start from epoch 3).
    """
    
    // MARK: - Epoch Detection
    
    /// Detects epoch from user input with full analysis.
    ///
    /// Creates a fresh `LanguageModelSession` per call to avoid
    /// conversation history contamination between detections.
    func detectEpoch(from userMessage: String) async throws -> EpochAnalysis {
        let session = LanguageModelSession(
            instructions: Self.instructions
        )
        
        let prompt = Prompt {
            "The user responded: \"\(userMessage)\""
            "Which epoch did they choose?"
        }
        
        let response = try await session.respond(
            to: prompt,
            generating: EpochAnalysis.self
        )
        
        print("[EPOCH] \(response.content.epoch.rawValue) | \(response.content.confidence.rawValue) | \(response.content.reasoning)")
        return response.content
    }
    
    /// Detects epoch and returns the app's Epoch enum with fallback handling.
    ///
    /// Returns the detected epoch if confidence is medium or high.
    /// Falls back to `.laFormazionePiloti` (start of the journey) on low confidence.
    func detectEpochEnum(from userMessage: String) async throws -> Epoch {
        let analysis = try await detectEpoch(from: userMessage)
        
        if !analysis.isLowConfidence {
            return analysis.epoch.toAppEpoch
        }
        
        print("[EPOCH WARNING] Low confidence, using fallback → laFormazionePiloti")
        return .laFormazionePiloti
    }
}
