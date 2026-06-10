//
//  MediaLibrary.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 18/12/25.
//
import Foundation

/// Central repository for all video and image assets with sequence generation.
///
/// Provides static collections of VideoConfig and ImageConfig assets, plus
/// video redirection for excluded
/// modules (VR suitability and time constraints), random selection with constraints, and
/// dynamic image discovery from epoch-specific folders.
struct MediaLibrary {
    
    static let videos: [VideoConfig] = [
        
        // MARK: - EPOCA 1 - CORSA COME SFIDA VIDEOS  -

        // MARK: - Introductory
        
        VideoConfig(
            title: "Introduzione",
            fileName: "EP01_PAN02_Stereo_Intro",
            category: .introductory,
            epochs: [.laCorsaComeSfida],
            modules: [.A1],
            hasAudio: true,
            targetSlot: 2,
            previewTime: 120,
            duration: 30.0,
         //endTime: 5,
         endTime: 117,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_10",
                useSpatialTransition: true,
                delayBeforeAnimation: 4.0
            )
        ),
        
        // MARK: - Standard Videos

        
        VideoConfig(
            title: "La Targa Florio",
            fileName: "EP01_PAN01_Stereo_TargaFlorio",
            category: .standard,
            epochs: [.laCorsaComeSfida],
            modules: [.B],
            hasAudio: true,
            targetSlot: 1,
            previewTime: 0.0,
            duration: 90,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),

        VideoConfig(
            title: "Il Gran Premio automobilistico d'Italia",
            fileName: "EP01_PAN03_Stereo_GranPremio",
            category: .standard,
            epochs: [.laCorsaComeSfida],
            modules: [.B],
            hasAudio: true,
            targetSlot: 3,
            previewTime: 0.0,
            duration: 120,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),

        VideoConfig(
            title: "Il Mondiale Sport Prototipi",
            fileName: "EP01_PAN04_Stereo_MondialeSportprototipi",
            category: .standard,
            epochs: [.laCorsaComeSfida],
            modules: [.B],
            hasAudio: true,
            targetSlot: 4,
            previewTime: 0.0,
            duration: 60.0,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),

        VideoConfig(
            title: "Inaugura l'Autodromo Nazionale di Monza",
            fileName: "EP01_PAN05_Stereo_Monza",
            category: .standard,
            epochs: [.laCorsaComeSfida],
            modules: [.B],
            hasAudio: true,
            targetSlot: 5,
            previewTime: 83,
            duration: 80,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),
        
        VideoConfig(
            title: "La Mille Miglia",
            fileName: "EP01_PAN06__Stereo_Mille-Miglia",
            category: .standard,
            epochs: [.laCorsaComeSfida],
            modules: [.B],
            hasAudio: true,
            targetSlot: 6,
            previewTime: 0.0,
            duration: 60.0,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),
        
        VideoConfig(
            title: "La dinastia Alfa Romeo",
            fileName: "EP01_PAN07_Stereo_Alfa-Romeo",
            category: .standard,
            epochs: [.laCorsaComeSfida],
            modules: [.B],
            hasAudio: true,
            targetSlot: 7,
            previewTime: 0.0,
            duration: 100.0,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),
        



        
        // MARK: - NextModuleIntro (B1)

        VideoConfig(
            title: "Ferrari 375 Plus (1954)",
            fileName: "EP01_PAN08_Stereo_Ferrari-375",
            category: .nextModuleIntro,
            epochs: [.laCorsaComeSfida],
            modules: [.B],
            introducesModule: .B,
            hasAudio: true,
            targetSlot: 8,
            previewTime: 0.0,
            duration: 60.0,
            endTime: nil,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_01",
                useSpatialTransition: false,
                mediaShouldMoveForward: false,
                mediaShouldMoveBackward: false,
            ),
            introducesCarModel: .ferrari375

        ),
        
        VideoConfig(
            title: "Alfa Romeo P3 (1932)",
            fileName: "EP01_PAN09_Stereo_Alfa-Romeo-P3",
            category: .nextModuleIntro,
            epochs: [.laCorsaComeSfida],
            modules: [.B],
            introducesModule: .B,
            hasAudio: true,
            targetSlot: 9,
            previewTime: 0.0,
            duration: 60.0,
            endTime: nil,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_01",
                useSpatialTransition: false,
                mediaShouldMoveForward: false,
                mediaShouldMoveBackward: false,
            ),
            introducesCarModel: .alfaRomeo
        ),
        
        
        VideoConfig(
            title: "L'Autodromo di Monza",
            fileName: "EP01_PAN10_Stereo_Monza-Diorama",
            category: .nextModuleIntro,
            epochs: [.laCorsaComeSfida],
            modules: [.C],
            introducesModule: .C,
            hasAudio: true,
            targetSlot: 10,
            previewTime: 0.0,
            duration: 60.0,
            endTime: nil,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_01",
                useSpatialTransition: false,
                mediaShouldMoveForward: false,
                mediaShouldMoveBackward: false,
            ),
            introducesDioramaModel: .monza
        ),

        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        // MARK: - EPOCA 2 - TECNICA PASSIONE E GENIO  -

        // MARK: - Introductory
        
        VideoConfig(
              title: "Introduzione",
              fileName: "EP02_PAN02_Stereo_Intro",
              category: .introductory,
              epochs: [.tecnicaPassioneGenio],
              modules: [.A1],
              hasAudio: true,
              targetSlot: 2,
              previewTime: 117,
              duration: 30.0,
             //endTime: 5,
             endTime: 115,
              animationConfig: AnimationConfig(
                panelAnimationName: "Activation_10",
                useSpatialTransition: true,
                delayBeforeAnimation: 4.0
              )
            ),
        
        
        
        // MARK: - Standard Videos

        
        VideoConfig(
            title: "La Lancia Stratos",
            fileName: "EP02_PAN01_Stereo_Lancia-Stratos",
            category: .standard,
            epochs: [.tecnicaPassioneGenio],
            modules: [.B],
            hasAudio: true,
            targetSlot: 1,
            previewTime: 0.0,
            duration: 90,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),

        VideoConfig(
            title: "Il Motorsport come Spettacolo",
            fileName: "EP02_PAN03_Miki-Biasion-world-rally-champ",
            category: .standard,
            epochs: [.tecnicaPassioneGenio],
            modules: [.B],
            hasAudio: true,
            targetSlot: 3,
            previewTime: 0.0,
            duration: 120,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),

        VideoConfig(
            title: "Il mestiere dell'imprevisto",
            fileName: "EP02_PAN04_Stereo_Rally",
            category: .standard,
            epochs: [.tecnicaPassioneGenio],
            modules: [.B],
            hasAudio: true,
            targetSlot: 4,
            previewTime: 0.0,
            duration: 60.0,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),

        VideoConfig(
            title: "Le Donne e il motorsport",
            fileName: "EP02_PAN05_Stereo_Donne-Motorsport",
            category: .standard,
            epochs: [.tecnicaPassioneGenio],
            modules: [.B],
            hasAudio: true,
            targetSlot: 5,
            previewTime: 83,
            duration: 80,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),
        
        VideoConfig(
            title: "Dominio Lancia: dalla 037 alla Delta Integrale",
            fileName: "EP02_PAN06_Dominio_Lancia",
            category: .standard,
            epochs: [.tecnicaPassioneGenio],
            modules: [.B],
            hasAudio: true,
            targetSlot: 6,
            previewTime: 0.0,
            duration: 60.0,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),
        
        VideoConfig(
            title: "L'era dei piloti atleti",
            fileName: "EP02_PAN07_Stereo_Piloti_Altleti",
            category: .standard,
            epochs: [.tecnicaPassioneGenio],
            modules: [.B],
            hasAudio: true,
            targetSlot: 7,
            previewTime: 0.0,
            duration: 100.0,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),
        

        
        
        
        // MARK: - NextModuleIntro

        VideoConfig(
            title: "Lancia Stratos HF (1974)",
            fileName: "EP02_PAN08_Stereo_3DModel_Lancia-Stratos",
            category: .nextModuleIntro,
            epochs: [.tecnicaPassioneGenio],
            modules: [.B],
            introducesModule: .B,
            hasAudio: true,
            targetSlot: 8,
            previewTime: 0.0,
            duration: 60.0,
            endTime: nil,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_01",
                useSpatialTransition: false,
                mediaShouldMoveForward: false,
                mediaShouldMoveBackward: false,
            ),
            introducesCarModel: .lanciaStratos

        ),
        
        VideoConfig(
            title: "Lancia Delta Integrale HF EVO2 (1994)",
            fileName: "EP02_PAN09_Stereo_3DModel_Lancia-Delta",
            category: .nextModuleIntro,
            epochs: [.tecnicaPassioneGenio],
            modules: [.B],
            introducesModule: .B,
            hasAudio: true,
            targetSlot: 9,
            previewTime: 0.0,
            duration: 60.0,
            endTime: nil,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_01",
                useSpatialTransition: false,
                mediaShouldMoveForward: false,
                mediaShouldMoveBackward: false,
            ),
            introducesCarModel: .deltaIntegrale
        ),
        
        
        VideoConfig(
            title: "In pista a Misano",
            fileName: "IntroEP02-PAN10_VR180",
            category: .nextModuleIntro,
            epochs: [.tecnicaPassioneGenio],
            modules: [.D],
            introducesModule: .D,
            hasAudio: true,
            targetSlot: 10,
            previewTime: 0.0,
            duration: 60.0,
        //    endTime: 27.0,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_01",
                useSpatialTransition: false,
                mediaShouldMoveForward: true,
                mediaShouldMoveBackward: true,
            ),
            crossfadeTriggerTime: 27.0,
            crossfadeDuration: 3.0
        ),

        
        

        

        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        // MARK: - EPOCA 3 - FORMAZIONE  -

        // MARK: - Introductory
        
        VideoConfig(
            title: "Introduzione",
            fileName: "EP03_PAN02_Stereo_Intro",
            category: .introductory,
            epochs: [.laFormazionePiloti],
            modules: [.A1],
            hasAudio: true,
            targetSlot: 2,
            previewTime: 106,
            duration: 30.0,
         //endTime: 5,
         endTime: 102,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_10",
                useSpatialTransition: true,
                delayBeforeAnimation: 4.0
            )
        ),
        
        
        
        // MARK: - Standard Videos

                
        
        VideoConfig(
            title: "Il Centro Guida Sicura di ACI",
            fileName: "EP03_PAN01_Stereo_Centro-Guida-Sicura",
            category: .standard,
            epochs: [.laFormazionePiloti],
            modules: [.B],
            hasAudio: true,
            targetSlot: 1,
            previewTime: 0.0,
            duration: 90,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),

        VideoConfig(
            title: "eSports",
            fileName: "EP03_PAN03_Stereo_eSports",
            category: .standard,
            epochs: [.laFormazionePiloti],
            modules: [.B],
            hasAudio: true,
            targetSlot: 3,
            previewTime: 0.0,
            duration: 120,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),
        
        
        VideoConfig(
            title: "La Formula 4",
            fileName: "EP03_PAN04_Stereo_Formula4",
            category: .standard,
            epochs: [.laFormazionePiloti],
            modules: [.B],
            hasAudio: true,
            targetSlot: 4,
            previewTime: 0.0,
            duration: 120,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),

        VideoConfig(
            title: "I sistemi di sicurezza",
            fileName: "EP03_PAN05_Stereo_Sistemi-sicurezza",
            category: .standard,
            epochs: [.laFormazionePiloti],
            modules: [.B],
            hasAudio: true,
            targetSlot: 5,
            previewTime: 0.0,
            duration: 60.0,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),

        VideoConfig(
            title: "La nascita della Formula E",
            fileName: "EP03_PAN06_Stereo_Formula-E",
            category: .standard,
            epochs: [.laFormazionePiloti],
            modules: [.B],
            hasAudio: true,
            targetSlot: 6,
            previewTime: 83,
            duration: 80,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),
        
        VideoConfig(
            title: "Le giovani generazioni",
            fileName: "EP03_PAN07_Stereo_Nuove-generazioni",
            category: .standard,
            epochs: [.laFormazionePiloti],
            modules: [.B],
            hasAudio: true,
            targetSlot: 7,
            previewTime: 0.0,
            duration: 60.0,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_08",
                useSpatialTransition: true,
                delayBeforeAnimation: 5.0
            )
        ),
        
        

        
        
        
        // MARK: - NextModuleIntro

        VideoConfig(
            title: "Tatuus F4-T-421",
            fileName: "EP03_PAN08_Stereo_Tatuus_3D_Model",
            category: .nextModuleIntro,
            epochs: [.laFormazionePiloti],
            modules: [.B],
            introducesModule: .B,
            hasAudio: true,
            targetSlot: 8,
            previewTime: 0.0,
            duration: 60.0,
            endTime: nil,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_01",
                useSpatialTransition: false,
                mediaShouldMoveForward: false,
                mediaShouldMoveBackward: false,
            ),
            introducesCarModel: .tatuus

        ),
        
        VideoConfig(
            title: "Il circuito di Vallelunga",
            fileName: "EP03_PAN09_Stereo_Vallelunga_Diorama",
            category: .nextModuleIntro,
            epochs: [.laFormazionePiloti],
            modules: [.C],
            introducesModule: .C,
            hasAudio: true,
            targetSlot: 9,
            previewTime: 0.0,
            duration: 60.0,
            endTime: nil,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_01",
                useSpatialTransition: false,
                mediaShouldMoveForward: false,
                mediaShouldMoveBackward: false,
            ),
            introducesDioramaModel: .valleLunga
        ),
        
        

        VideoConfig(
            title: "In pista a Misano",
            fileName: "IntroEP02-PAN10_VR180",
            category: .nextModuleIntro,
            epochs: [.laFormazionePiloti],
            modules: [.D],
            introducesModule: .D,
            hasAudio: true,
            targetSlot: 10,
            previewTime: 0.0,
            duration: 60.0,
         //   endTime: 27.0,
            animationConfig: AnimationConfig(
                panelAnimationName: "Activation_01",
                useSpatialTransition: false,
                mediaShouldMoveForward: true,
                mediaShouldMoveBackward: true,
            ),
            crossfadeTriggerTime: 27,
            crossfadeDuration: 3.0
        ),

        
    ]
  
        
        // MARK: - Basic Accessors
        
        
        
        /// Returns the introductory video for a specific module and epoch.
        static func introductoryVideo(for module: ModuleType, epoch: Epoch) -> VideoConfig? {
            videos.first { $0.isIntroductory && $0.isAvailable(for: module) && $0.isAvailable(for: epoch) }
        }

        
    }
