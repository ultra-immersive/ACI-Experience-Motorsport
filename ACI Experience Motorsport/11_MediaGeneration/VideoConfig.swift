//
//  VideoConfig.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 18/12/25.
//

import Foundation

/// Configuration for a video asset with epoch/module filtering and animation coordination.
struct VideoConfig {
    let id: UUID = UUID()
    let title: String
    let fileName: String
    let category: VideoCategory
    let epochs: Set<Epoch>
    let modules: Set<ModuleType>
    let introducesModule: ModuleType?
    let hasAudio: Bool
    let fileExtension: String
    let targetSlot: Int?  
    let previewTime: Double
    let duration: TimeInterval
    let endTime: TimeInterval?
    let animationConfig: AnimationConfig?
    var introducesCarModel: ReducedCarModel? = nil
    var introducesDioramaModel: DioramaModel? = nil
    let crossfadeTriggerTime: TimeInterval?
    let crossfadeDuration: TimeInterval

    init(
        title: String = "Test Temporary Title",
        fileName: String,
        category: VideoCategory = .standard,
        epochs: Set<Epoch> = [.all],
        modules: Set<ModuleType> = [],
        introducesModule: ModuleType? = nil,
        hasAudio: Bool = false,
        fileExtension: String = "mov",
        targetSlot: Int? = nil,
        previewTime: Double = 0.0,
        duration: TimeInterval,
        endTime: TimeInterval? = nil,
        animationConfig: AnimationConfig? = nil,
        introducesCarModel: ReducedCarModel? = nil,
        introducesDioramaModel: DioramaModel? = nil,
        crossfadeTriggerTime: TimeInterval? = nil,
        crossfadeDuration: TimeInterval = 3.0
    ) {
        self.title = title
        self.fileName = fileName
        self.category = category
        self.epochs = epochs
        self.modules = modules
        self.introducesModule = introducesModule
        self.hasAudio = hasAudio
        self.fileExtension = fileExtension
        self.targetSlot = targetSlot
        self.previewTime = previewTime
        self.duration = duration
        self.endTime = endTime
        self.animationConfig = animationConfig
        self.introducesCarModel = introducesCarModel
        self.introducesDioramaModel = introducesDioramaModel
        self.crossfadeTriggerTime = crossfadeTriggerTime
        self.crossfadeDuration = crossfadeDuration
    }
    
    // MARK: - Computed Properties
    
    var isIntroductory: Bool { category == .introductory }
    var isStandard: Bool { category == .standard }
    var isNextModuleIntro: Bool { category == .nextModuleIntro }
    
    var hasCustomEndTime: Bool { endTime != nil }
    
    var effectiveDuration: TimeInterval { endTime ?? duration }
    
    // MARK: - Availability
    
    func isAvailable(for epoch: Epoch) -> Bool {
        epochs.contains(.all) || epochs.contains(epoch)
    }
    
    func isAvailable(for module: ModuleType) -> Bool {
        modules.isEmpty || modules.contains(module)
    }
}
