//
//  AppModel.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 16/10/25.
//

import SwiftUI
import AVFoundation
import RealityKit

/// Central state manager for the experience configuration and AI-driven functionalities.
///
/// Coordinates epoch selection, module availability, time-based content filtering, and VR suitability
/// assessments. Integrates AI detection results to dynamically configure the experience based on
/// user preferences and time constraints.
@MainActor
@Observable
class AppModel {
    
    var availableModules: [ModuleType] = AppModel.modules(for: .laFormazionePiloti)
    
    var selectedEpoch: Epoch = .laFormazionePiloti {
        didSet {
            print("Selected epoch is: \(selectedEpoch.displayName)")
            availableModules = Self.modules(for: selectedEpoch)
            activeReducedCarModel = nil
            activeDioramaModel = nil
        }
    }
    
    var reducedCarModels: [ReducedCarModel] {
        ReducedCarModel.allCases.filter { $0.epochs.contains(selectedEpoch) }
    }
    var activeReducedCarModel: ReducedCarModel? = nil
    var currentReducedCarModel: ReducedCarModel {
        activeReducedCarModel ?? reducedCarModels.first ?? .tatuus
    }

    
    var activeDioramaModel: DioramaModel? = nil
    var dioramaModel: DioramaModel {
        activeDioramaModel ?? DioramaModel.allCases.first { $0.epochs.contains(selectedEpoch) } ?? .valleLunga
    }

    var videoManager: VideoManager {
         if _videoManager == nil {
             _videoManager = VideoManager()
         }
         return _videoManager!
     }
    var _videoManager: VideoManager?
    
    let player: AVPlayer
    init() {
        self.player = AVPlayer()
    }

    var currentEpochAnalysis: EpochAnalysis? = nil
    // MARK: - Module Configuration
    
    /// Returns the available modules for a specific epoch based on content availability.
    ///
    /// Each epoch has a predefined set of compatible module types that match its historical
    /// period and available content assets.
    static func modules(for epoch: Epoch) -> [ModuleType] {
        switch epoch {
        case .all:
            return [.A1, .B, .C, .D]
        case .laCorsaComeSfida:
            return [.A1, .B, .C]
        case .tecnicaPassioneGenio:
            return [.A1, .B, .D]
        case .laFormazionePiloti:
            return [.A1, .B, .C, .D]
        }
    }
    
    // MARK: - AI Detection Updates
    
    /// Updates the selected epoch based on AI analysis results.
    ///
    /// Processes the epoch detection analysis and updates the selected epoch
    func updateEpoch(with analysis: EpochAnalysis) {
        self.currentEpochAnalysis = analysis
        let epoch = analysis.epoch.toAppEpoch
        self.selectedEpoch = epoch
    }
}

// MARK: - Epoch Definition

/// Historical periods of Italian motorsport.
///
enum Epoch: String, Codable, CaseIterable, Identifiable {
    case all = "all"
    case laCorsaComeSfida = "la_corsa_come_sfida"
    case tecnicaPassioneGenio = "tecnica_passione_genio"
    case laFormazionePiloti = "la_formazione_piloti"
    
    var id: String { self.rawValue }
        
    var displayName: String {
        switch self {
        case .all: return "Tutte le Epoche"
        case .laCorsaComeSfida: return "EPOCA 1 - La corsa come sfida"
        case .tecnicaPassioneGenio: return "EPOCA 3 - Tecnica, passione e genio"
        case .laFormazionePiloti: return "EPOCA 4 - La formazione che crea i piloti"
        }
    }
}

// MARK: - Asset Models

/// 3D diorama models mapped to specific historical epochs.
enum DioramaModel: String, Codable, CaseIterable {
    case monza = "A_Monza_Diorama"
    case valleLunga = "A_Diorama"

    var epochs: Set<Epoch> {
        switch self {
        case .monza: return [.laCorsaComeSfida]
        case .valleLunga: return [.laFormazionePiloti]
        }
    }

    var displayName: String {
        switch self {
        case .monza: return "Monza Diorama"
        case .valleLunga: return "Vallelunga Diorama"
        }
    }
}

/// Reduced car models for visualization, each associated with specific epochs.
enum ReducedCarModel: String, Codable, CaseIterable {
    case alfaRomeo = "A_AlfaRomeo"
    case tatuus = "A_Tatuus"
    case ferrari375 = "A_Ferrari_02"
    case lanciaStratos = "A_LanciaStratos"
    case deltaIntegrale = "A_DeltaIntegrale"

    var epochs: Set<Epoch> {
        switch self {
        case .tatuus: return [.laFormazionePiloti]
        case .alfaRomeo: return [.laCorsaComeSfida]
        case .ferrari375: return [.laCorsaComeSfida]
        case .lanciaStratos: return [.tecnicaPassioneGenio]
        case .deltaIntegrale: return [.tecnicaPassioneGenio]
        }
    }

    var displayName: String {
        switch self {
        case .alfaRomeo: return "Alfa Romeo 8C"
        case .tatuus: return "Tatuus Formula 4"
        case .ferrari375: return "Ferrari 375"
        case .lanciaStratos: return "Lancia Stratos"
        case .deltaIntegrale: return "Delta Integrale"
        }
    }
}

// MARK: - Module Types

/// Content module types with duration estimates and display formatting.
///
/// Represents different experience modules ranging from image displays to full-scale
enum ModuleType: String, Codable, CaseIterable {
    case A1, B, C, D
}
