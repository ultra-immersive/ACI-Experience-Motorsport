//
//  ODRVideoManager.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 27/10/25.
//

import Foundation
import AVKit
import Combine

/// Manages on-demand video resource downloads with progress tracking and verification.
///
/// Coordinates downloading of video assets using Apple's On-Demand Resources (ODR) system,
/// providing progress updates, sequential download management, and resource lifecycle control.
/// Maintains active resource requests to keep downloaded content accessible throughout the experience.
class ODRManager: ObservableObject {
    static let shared = ODRManager()
    
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloading: Bool = false
    @Published var downloadError: Error?
    
    @Published var currentDownloadingVideo: String?
    @Published var videosDownloaded: Int = 0
    @Published var totalVideosToDownload: Int = 0
    @Published var downloadPhase: DownloadPhase = .idle
    @Published var isFinalizing: Bool = false
    
    private var activeRequests: [NSBundleResourceRequest] = []
    
    enum DownloadPhase: Equatable {
        case idle
        case checking
        case downloading
        case verifying
        case completed
        case failed(String)
    }
    
    /// Video resource tags mapped to their corresponding file names and display names.
    enum VideoTag: String, CaseIterable {

        
        case EP01_PAN01_Stereo_TargaFlorio = "EP01_PAN01_Stereo_TargaFlorio"
        case EP01_PAN02_Stereo_Intro = "EP01_PAN02_Stereo_Intro"
        case EP01_PAN03_Stereo_GranPremio = "EP01_PAN03_Stereo_GranPremio"
        case EP01_PAN04_Stereo_MondialeSportprototipi = "EP01_PAN04_Stereo_MondialeSportprototipi"
        case EP01_PAN05_Stereo_Monza = "EP01_PAN05_Stereo_Monza"
        case EP01_PAN06__Stereo_Mille_Miglia = "EP01_PAN06__Stereo_Mille-Miglia"
        case EP01_PAN07_Stereo_Alfa_Romeo = "EP01_PAN07_Stereo_Alfa-Romeo"
        case EP01_PAN08_Stereo_Ferrari_375 = "EP01_PAN08_Stereo_Ferrari-375"
        case EP01_PAN09_Stereo_Alfa_Romeo_P3 = "EP01_PAN09_Stereo_Alfa-Romeo-P3"
        case EP01_PAN10_Stereo_Monza_Diorama = "EP01_PAN10_Stereo_Monza-Diorama"
        
        case EP02_PAN01_Stereo_LanciaStratos = "EP02_PAN01_Stereo_Lancia-Stratos"
        case EP02_PAN02_Stereo_Intro = "EP02_PAN02_Stereo_Intro"
        case EP02_PAN03_MikiBiasionworldrallychamp = "EP02_PAN03_Miki-Biasion-world-rally-champ"
        case EP02_PAN04_Stereo_Rally = "EP02_PAN04_Stereo_Rally"
        case EP02_PAN05_Stereo_DonneMotorsport = "EP02_PAN05_Stereo_Donne-Motorsport"
        case EP02_PAN06_Dominio_Lancia = "EP02_PAN06_Dominio_Lancia"
        case EP02_PAN07_Stereo_Piloti_Altleti = "EP02_PAN07_Stereo_Piloti_Altleti"
        case EP02_PAN08_Stereo_3DModel_LanciaStratos = "EP02_PAN08_Stereo_3DModel_Lancia-Stratos"
        case EP02_PAN09_Stereo_3DModel_LanciaDelta = "EP02_PAN09_Stereo_3DModel_Lancia-Delta"
        
        case EP03_PAN01_Stereo_CentroGuidaSicura = "EP03_PAN01_Stereo_Centro-Guida-Sicura"
        case EP03_PAN02_Stereo_Intro = "EP03_PAN02_Stereo_Intro"
        case EP03_PAN03_Stereo_eSports = "EP03_PAN03_Stereo_eSports"
        case EP03_PAN04_Stereo_Formula4 = "EP03_PAN04_Stereo_Formula4"
        case EP03_PAN05_Stereo_Sistemisicurezza = "EP03_PAN05_Stereo_Sistemi-sicurezza"
        case EP03_PAN06_Stereo_FormulaE = "EP03_PAN06_Stereo_Formula-E"
        case EP03_PAN07_Stereo_Nuovegenerazioni = "EP03_PAN07_Stereo_Nuove-generazioni"
        case EP03_PAN08_Stereo_Tatuus_3D_Model = "EP03_PAN08_Stereo_Tatuus_3D_Model"
        case EP03_PAN09_Stereo_Vallelunga_Diorama = "EP03_PAN09_Stereo_Vallelunga_Diorama"
        
        
        
        case IntroEP02PAN10_VR180 = "IntroEP02-PAN10_VR180"
        case IntroEP02PAN10_VR180_HDR_MVHEVC = "IntroEP02-PAN10_VR180_HDR_MV-HEVC"

        var videoFileName: String {
            switch self {
                
            case .EP01_PAN01_Stereo_TargaFlorio: return "EP01_PAN01_Stereo_TargaFlorio"
            case .EP01_PAN02_Stereo_Intro: return "EP01_PAN02_Stereo_Intro"
            case .EP01_PAN03_Stereo_GranPremio: return "EP01_PAN03_Stereo_GranPremio"
            case .EP01_PAN04_Stereo_MondialeSportprototipi: return "EP01_PAN04_Stereo_MondialeSportprototipi"
            case .EP01_PAN05_Stereo_Monza: return "EP01_PAN05_Stereo_Monza"
            case .EP01_PAN06__Stereo_Mille_Miglia: return "EP01_PAN06__Stereo_Mille-Miglia"
            case .EP01_PAN07_Stereo_Alfa_Romeo: return "EP01_PAN07_Stereo_Alfa-Romeo"
            case .EP01_PAN08_Stereo_Ferrari_375: return "EP01_PAN08_Stereo_Ferrari-375"
            case .EP01_PAN09_Stereo_Alfa_Romeo_P3: return "EP01_PAN09_Stereo_Alfa-Romeo-P3"
            case .EP01_PAN10_Stereo_Monza_Diorama: return "EP01_PAN10_Stereo_Monza-Diorama"
                
                
            case .EP02_PAN01_Stereo_LanciaStratos: return "EP02_PAN01_Stereo_Lancia-Stratos"
            case .EP02_PAN02_Stereo_Intro: return "EP02_PAN02_Stereo_Intro"
            case .EP02_PAN03_MikiBiasionworldrallychamp: return "EP02_PAN03_Miki-Biasion-world-rally-champ"
            case .EP02_PAN04_Stereo_Rally: return "EP02_PAN04_Stereo_Rally"
            case .EP02_PAN05_Stereo_DonneMotorsport: return "EP02_PAN05_Stereo_Donne-Motorsport"
            case .EP02_PAN06_Dominio_Lancia: return "EP02_PAN06_Dominio_Lancia"
            case .EP02_PAN07_Stereo_Piloti_Altleti: return "EP02_PAN07_Stereo_Piloti_Altleti"
            case .EP02_PAN08_Stereo_3DModel_LanciaStratos: return "EP02_PAN08_Stereo_3DModel_Lancia-Stratos"
            case .EP02_PAN09_Stereo_3DModel_LanciaDelta: return "EP02_PAN09_Stereo_3DModel_Lancia-Delta"
                
                
            case .EP03_PAN01_Stereo_CentroGuidaSicura: return "EP03_PAN01_Stereo_Centro-Guida-Sicura"
            case .EP03_PAN02_Stereo_Intro: return "EP03_PAN02_Stereo_Intro"
            case .EP03_PAN03_Stereo_eSports: return "EP03_PAN03_Stereo_eSports"
            case .EP03_PAN04_Stereo_Formula4: return "EP03_PAN04_Stereo_Formula4"
            case .EP03_PAN05_Stereo_Sistemisicurezza: return "EP03_PAN05_Stereo_Sistemi-sicurezza"
            case .EP03_PAN06_Stereo_FormulaE: return "EP03_PAN06_Stereo_Formula-E"
            case .EP03_PAN07_Stereo_Nuovegenerazioni: return "EP03_PAN07_Stereo_Nuove-generazioni"
            case .EP03_PAN08_Stereo_Tatuus_3D_Model: return "EP03_PAN08_Stereo_Tatuus_3D_Model"
            case .EP03_PAN09_Stereo_Vallelunga_Diorama: return "EP03_PAN09_Stereo_Vallelunga_Diorama"
            
                
                
            case .IntroEP02PAN10_VR180: return "IntroEP02-PAN10_VR180"
          case .IntroEP02PAN10_VR180_HDR_MVHEVC: return "IntroEP02-PAN10_VR180_HDR_MV-HEVC"
            }
        }
        
        var displayName: String {
            videoFileName.replacingOccurrences(of: "_", with: " ")
        }
    }
    
    // MARK: - Availability Checking
    
    /// Checks if a video resource is already downloaded and accessible.
    ///
    /// First attempts to locate the video in the main bundle, then conditionally checks
    /// if the ODR resource is available without initiating a download.
    func isVideoAvailable(tag: VideoTag) -> Bool {
        if Bundle.main.url(forResource: tag.videoFileName, withExtension: "mov") != nil {
            return true
        }
        
        let tags = Set([tag.rawValue])
        let request = NSBundleResourceRequest(tags: tags)
        
        var isAvailable = false
        request.conditionallyBeginAccessingResources { available in
            isAvailable = available
            if available {
                request.endAccessingResources()
            }
        }
        
        return isAvailable
    }
    
    // MARK: - Single Video Download
    
    /// Downloads a single video resource with progress tracking.
    ///
    /// Creates a high-priority ODR request, monitors download progress, and returns the video URL
    /// upon successful completion. Maintains the resource request to keep the video accessible.
    func downloadVideo(tag: VideoTag, completion: @escaping (Result<URL, Error>) -> Void) {
        if let url = Bundle.main.url(forResource: tag.videoFileName, withExtension: "mov") {
            completion(.success(url))
            return
        }
        
        let tags = Set([tag.rawValue])
        let request = NSBundleResourceRequest(tags: tags)
        activeRequests.append(request)
        
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        
        DispatchQueue.main.async {
            self.isDownloading = true
            self.downloadProgress = 0.0
            self.downloadError = nil
        }
        
        let progressObserver = request.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.downloadProgress = progress.fractionCompleted
            }
        }
        
        request.beginAccessingResources { [weak self] error in
            DispatchQueue.main.async {
                self?.isDownloading = false
                
                if let error = error {
                    self?.downloadError = error
                    completion(.failure(error))
                } else if let url = Bundle.main.url(forResource: tag.videoFileName, withExtension: "mov") {
                    completion(.success(url))
                } else {
                    let notFoundError = NSError(
                        domain: "ODRManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Video file not found after download: \(tag.videoFileName)"]
                    )
                    self?.downloadError = notFoundError
                    completion(.failure(notFoundError))
                }
                
                progressObserver.invalidate()
            }
        }
    }
    
    // MARK: - Batch Download
    
    /// Downloads multiple video resources sequentially with detailed progress tracking.
    ///
    /// Filters out already-available videos, downloads remaining resources one at a time,
    /// and provides granular progress updates showing per-video and overall completion status.
    func downloadVideos(tags: [VideoTag], completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.async {
            self.downloadPhase = .checking
            self.isFinalizing = false
            self.videosDownloaded = 0
            self.downloadProgress = 0.0
        }
        
        let videosToDownload = tags.filter { !isVideoAvailable(tag: $0) }
        
        let alreadyAvailableCount = tags.count - videosToDownload.count
        
        DispatchQueue.main.async {
            self.totalVideosToDownload = tags.count
            self.videosDownloaded = alreadyAvailableCount
        }
        
        if videosToDownload.isEmpty {
            print("----------All videos already available------------")
            DispatchQueue.main.async {
                self.downloadPhase = .completed
                self.downloadProgress = 1.0
            }
            completion(.success(()))
            return
        }
        
        print("Need to download \(videosToDownload.count) videos, \(alreadyAvailableCount) already available")
        
        DispatchQueue.main.async {
            self.isDownloading = true
            self.downloadError = nil
            self.downloadPhase = .downloading
        }
        
        downloadSequentially(
            videos: videosToDownload,
            totalCount: tags.count,
            alreadyDownloaded: alreadyAvailableCount,
            completion: completion
        )
    }
    
    /// Recursively downloads videos one at a time with per-video progress updates.
    ///
    /// Handles sequential download orchestration, progress calculation combining completed and
    /// in-progress videos, and error handling with descriptive failure messages.
    private func downloadSequentially(
        videos: [VideoTag],
        totalCount: Int,
        alreadyDownloaded: Int,
        currentIndex: Int = 0,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard currentIndex < videos.count else {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.currentDownloadingVideo = nil
                self.downloadProgress = 1.0
                self.downloadPhase = .completed
                self.verifyDownloadedVideos(tags: videos)
            }
            completion(.success(()))
            return
        }
        
        let tag = videos[currentIndex]
        let completedVideos = alreadyDownloaded + currentIndex
        
        DispatchQueue.main.async {
            self.currentDownloadingVideo = tag.displayName
            self.videosDownloaded = completedVideos
            let baseProgress = Double(completedVideos) / Double(totalCount)
            self.downloadProgress = baseProgress
        }
        
        let tags = Set([tag.rawValue])
        let request = NSBundleResourceRequest(tags: tags)
        activeRequests.append(request)
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        
        let progressObserver = request.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let completedVideos = alreadyDownloaded + currentIndex
                let baseProgress = Double(completedVideos) / Double(totalCount)
                let videoContribution = (1.0 / Double(totalCount)) * progress.fractionCompleted
                self.downloadProgress = baseProgress + videoContribution
            }
        }
        
        request.beginAccessingResources { [weak self] error in
            progressObserver.invalidate()
            
            if let error = error {
                let detailedError = NSError(
                    domain: "ODRManager",
                    code: (error as NSError).code,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to download '\(tag.displayName)': \(error.localizedDescription)",
                        NSUnderlyingErrorKey: error
                    ]
                )
                
                DispatchQueue.main.async {
                    print("Download failed for \(tag.videoFileName): \(error)")
                    self?.isDownloading = false
                    self?.downloadError = detailedError
                    self?.downloadPhase = .failed(detailedError.localizedDescription)
                }
                completion(.failure(detailedError))
                return
            }
            
            if Bundle.main.url(forResource: tag.videoFileName, withExtension: "mov") != nil {
                print(" Downloaded Video : \(tag.videoFileName)")
            } else {
                let notFoundError = NSError(
                    domain: "ODRManager",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Video '\(tag.displayName)' not found after download. Check that the ODR tag '\(tag.rawValue)' matches the asset catalog tag."
                    ]
                )
                
                DispatchQueue.main.async {
                    print("Download reported success but file not found: \(tag.videoFileName)")
                    self?.isDownloading = false
                    self?.downloadError = notFoundError
                    self?.downloadPhase = .failed(notFoundError.localizedDescription)
                }
                completion(.failure(notFoundError))
                return
            }
            
            self?.downloadSequentially(
                videos: videos,
                totalCount: totalCount,
                alreadyDownloaded: alreadyDownloaded,
                currentIndex: currentIndex + 1,
                completion: completion
            )
        }
    }
    
    /// Verifies that all downloaded videos are accessible in the bundle.
    ///
    /// Attempts to locate each video file and reports success/failure counts for debugging.
    private func verifyDownloadedVideos(tags: [VideoTag]) {
        var successCount = 0
        var failCount = 0
        
        for tag in tags {
            if Bundle.main.url(forResource: tag.videoFileName, withExtension: "mov") != nil {
                successCount += 1
            } else {
                print("  \(tag.videoFileName).mov NOT accessible")
                failCount += 1
            }
        }
        
        print(" ------- \(successCount) videos accessible, \(failCount) not accessible -----")
    }
    
    // MARK: - Resource Access
        
    /// Releases all active resource requests to allow system resource cleanup.
    ///
    /// Should be called when the experience ends or resources are no longer needed.
    func endAccessingResources() {
        for request in activeRequests {
            request.endAccessingResources()
        }
        activeRequests.removeAll()
    }
}
