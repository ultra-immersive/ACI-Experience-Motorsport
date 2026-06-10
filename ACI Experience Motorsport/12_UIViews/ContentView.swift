import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import AVFoundation
import Speech

/// Primary entry view managing authorization checks, content downloads, and immersive space opening.
///
/// Coordinates the pre-experience workflow including hand tracking authorization, microphone access,
/// speech recognition permissions, and on-demand video resource downloads. Provides visual feedback
/// for each phase (checking, downloading, ready, failed) and handles automatic immersive space
/// transition when all prerequisites are met.
struct ContentView: View {
    @AppStorage("hasConfiguredFullScaleCar") private var hasConfigured = false
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    @StateObject private var odrManager = ODRManager.shared
    
    @State private var authorizationFailed = false
    @State private var authorizationFailureReason: AuthorizationFailure = .handTracking
    @State private var isChecking = true
    @State private var videosChecked = false
    @State private var allVideosAvailable = false
    @State private var downloadFailed = false
    @State var isContentViewActive: Bool = false
    
    @State private var iconRotation: Double = 0
    @State private var iconScale: Double = 1.0
    @State private var pulseOpacity: Double = 0.3
    
    private let requiredVideos: [ODRManager.VideoTag] = ODRManager.VideoTag.allCases
    
    /// Authorization failure types with user-friendly messaging.
    ///
    /// Represents different permission failures that can prevent the experience from launching,
    /// each with tailored titles, descriptions, and icons for clear user communication.
    enum AuthorizationFailure {
        case handTracking
        case microphone
        case speechRecognition
        case speechModelDownload
        
        var title: String {
            switch self {
            case .handTracking:
                return "Hand Tracking Required"
            case .microphone:
                return "Microphone Access Required"
            case .speechRecognition:
                return "Speech Recognition Required"
            case .speechModelDownload:
                return "Speech Model Required"
            }
        }
        
        var description: String {
            switch self {
            case .handTracking:
                return "Please enable hand tracking permission in Settings to continue"
            case .microphone:
                return "Please enable microphone access in Settings"
            case .speechRecognition:
                return "Please enable speech recognition in Settings"
            case .speechModelDownload:
                return "The Italian speech model could not be downloaded. Please check your internet connection and try again."
            }
        }
        
        var icon: String {
            switch self {
            case .handTracking:
                return "hand.raised.fill"
            case .microphone:
                return "mic.slash.fill"
            case .speechRecognition:
                return "waveform.badge.exclamationmark"
            case .speechModelDownload:
                return "arrow.down.circle"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if !hasConfigured {
                // Show inline staff config
                StaffConfigView {
                    hasConfigured = true
                }
                .frame(height: 1000)
            } else if authorizationFailed {
                authorizationFailedView
            } else if !videosChecked {
                loadingView
            } else if allVideosAvailable && !odrManager.isDownloading {
                launchingView
            } else if odrManager.isDownloading {
                downloadingView
            } else if downloadFailed {
                downloadFailedView
            } else {
                readyToStartView
            }
        }
        .frame(width: 620, height: 420)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if isContentViewActive && hasConfigured {
                    Task { await checkAuthorization() }
                }
            }
        }
        .onChange(of: hasConfigured) { oldValue, newValue in
            if newValue && !oldValue {
                Task { await checkAuthorization() }
            }
        }
        .onChange(of: scenePhase, initial: true) { (oldValue, newValue) in
            
            if newValue == .active && oldValue == .inactive {
                Task {
                    await checkAuthorization()
                }
            }
            
            if newValue == .active {
                isContentViewActive = true
            } else if newValue == .inactive {
                isContentViewActive = false
            } else if newValue == .background {
                isContentViewActive = false
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
        }
        .padding(40)
    }
    
    private var launchingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
        }
        .padding(40)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                Task {
                    await openImmersiveSpace(id: "ImmersiveSpace")
                    dismiss()
                }
            }
        }
    }
    
    private var downloadingView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(pulseOpacity))
                    .frame(width: 80, height: 80)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            pulseOpacity = 0.1
                        }
                    }
                
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            VStack(spacing: 8) {
                Text("Downloading Content")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Preparing spatial videos for your experience")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 16) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.ultraThinMaterial)
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geometry.size.width * odrManager.downloadProgress), height: 12)
                            .animation(.easeInOut(duration: 0.3), value: odrManager.downloadProgress)
                    }
                }
                .frame(height: 12)
                .frame(width: 420)
                
                HStack {
                    HStack(spacing: 4) {
                        Text("\(Int(odrManager.downloadProgress * 100))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.2), value: odrManager.downloadProgress)
                        Text("%")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "film.stack")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(odrManager.videosDownloaded)")
                            .fontWeight(.semibold)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.2), value: odrManager.videosDownloaded)
                        Text("of \(odrManager.totalVideosToDownload)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
                .frame(width: 420)
                
                if let currentVideo = odrManager.currentDownloadingVideo {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        
                        Text(currentVideo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 50)
        .padding(.vertical, 40)
        .glassBackgroundEffect()
    }
    
    // MARK: - Speech Model Download
    
    /// Ensures the Italian speech-to-text model is installed on-device.
    ///
    /// Checks `SpeechTranscriber.installedLocales` and triggers an
    /// `AssetInventory` download if the model is missing. This prevents
    /// the "No compatible audio format found" error on fresh devices.
    private func checkSpeechModelAvailability() async -> Bool {
        let locale = SpokenWordTranscriber.locale
        
        // 1. Is the locale supported at all?
        guard await SpeechTranscriber.supportedLocales.contains(where: {
            $0.identifier(.bcp47) == locale.identifier(.bcp47)
        }) else {
            print(" Italian not in SpeechTranscriber.supportedLocales")
            return false
        }
        
        // 2. Already installed? Done.
        if await SpeechTranscriber.installedLocales.contains(where: {
            $0.identifier(.bcp47) == locale.identifier(.bcp47)
        }) {
            return true
        }
        
        // 3. Download via AssetInventory
        print(" Italian speech model not installed — downloading...")
        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .progressiveTranscription
        )
        
        do {
            if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await downloader.downloadAndInstall()
            }
            return true
        } catch {
            print("Speech model download failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private var downloadFailedView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.red.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
            }
            
            VStack(spacing: 8) {
                Text("Download Failed")
                    .font(.title)
                    .fontWeight(.semibold)
                
                if let error = odrManager.downloadError {
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
            }
            
            Button {
                downloadFailed = false
                downloadVideos()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(40)
        .glassBackgroundEffect()
    }
    
    private var readyToStartView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: allVideosAvailable)
            }
            
            VStack(spacing: 8) {
                Text("Ready to Begin")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("All content has been downloaded successfully")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                Task {
                    await openImmersiveSpace(id: "ImmersiveSpace")
                    dismiss()
                }
            } label: {
                HStack(spacing: 10) {
                    Text("Enter Experience")
                    Image(systemName: "arrow.right.circle.fill")
                }
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(40)
        .glassBackgroundEffect()
    }
    
    private var authorizationFailedView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: authorizationFailureReason.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
            }
            
            VStack(spacing: 8) {
                Text(authorizationFailureReason.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(authorizationFailureReason.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 350)
            }
            
            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: "App-prefs:") {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    Task {
                        await checkAuthorization()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Check Again")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .glassBackgroundEffect()
    }
    
    // MARK: - Authorization
    
    /// Sequentially checks all required permissions for the experience.
    ///
    /// Verifies hand tracking, microphone, and speech recognition permissions in order,
    /// stopping at the first failure and displaying the appropriate error UI. Proceeds
    /// to video checking if all permissions are granted.
    private func checkAuthorization() async {
        isChecking = true
        authorizationFailed = false
        
#if targetEnvironment(simulator)
        checkVideosAndProceed()
#else
        
        let handTrackingAuthorized = await checkHandTrackingAuthorization()
        guard handTrackingAuthorized else {
            isChecking = false
            authorizationFailed = true
            authorizationFailureReason = .handTracking
            return
        }
        
        let microphoneAuthorized = await checkMicrophoneAuthorization()
        guard microphoneAuthorized else {
            isChecking = false
            authorizationFailed = true
            authorizationFailureReason = .microphone
            return
        }
        
        let speechAuthorized = await checkSpeechRecognitionAuthorization()
        guard speechAuthorized else {
            isChecking = false
            authorizationFailed = true
            authorizationFailureReason = .speechRecognition
            return
        }
        
        // ── NEW: Ensure on-device Italian speech model is present ──
        let modelReady = await checkSpeechModelAvailability()
        guard modelReady else {
            isChecking = false
            authorizationFailed = true
            authorizationFailureReason = .speechModelDownload
            return
        }
        
        checkVideosAndProceed()
        
#endif
    }
    
    /// Checks or requests hand tracking authorization from ARKit.
    ///
    /// Handles already-granted, denied, and not-determined authorization states,
    /// automatically requesting permission when needed.
    private func checkHandTrackingAuthorization() async -> Bool {
        let session = ARKitSession()
        let handTrackingProvider = HandTrackingProvider()
        
        let authorizationStatus = await session.queryAuthorization(for: [.handTracking])
        
        switch authorizationStatus[.handTracking] {
        case .allowed:
            print(" Hand tracking already authorized")
            return true
            
        case .denied:
            print(" Hand tracking denied by user")
            return false
            
        case .notDetermined:
            print(" Requesting hand tracking authorization...")
            do {
                try await session.run([handTrackingProvider])
                print(" Hand tracking authorized")
                session.stop()
                return true
            } catch {
                print(" Hand tracking authorization failed: \(error.localizedDescription)")
                return false
            }
            
        case .none:
            print("None")
            return false
        @unknown default:
            print("Unknown hand tracking authorization status")
            return false
        }
    }
    
    /// Checks or requests microphone access permission.
    ///
    /// Handles granted, denied, and undetermined states, automatically requesting
    /// permission when needed for voice input functionality.
    private func checkMicrophoneAuthorization() async -> Bool {
        let currentStatus = AVAudioApplication.shared.recordPermission
        
        switch currentStatus {
        case .granted:
            print(" Microphone already authorized")
            return true
            
        case .denied:
            print(" Microphone denied by user")
            return false
            
        case .undetermined:
            print("🔄 Requesting microphone authorization...")
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            
            if granted {
                print("Microphone authorized")
            } else {
                print(" Microphone authorization denied")
            }
            return granted
            
        @unknown default:
            print(" Unknown microphone authorization status")
            return false
        }
    }
    
    /// Checks or requests speech recognition permission.
    ///
    /// Handles authorized, denied/restricted, and not-determined states, automatically
    /// requesting permission when needed for transcription functionality.
    private func checkSpeechRecognitionAuthorization() async -> Bool {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        
        switch currentStatus {
        case .authorized:
            print(" Speech recognition already authorized")
            return true
            
        case .denied, .restricted:
            print(" Speech recognition denied or restricted")
            return false
            
        case .notDetermined:
            print(" Requesting speech recognition authorization...")
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            
            if granted {
                print(" Speech recognition authorized")
            } else {
                print(" Speech recognition authorization denied")
            }
            return granted
            
        @unknown default:
            print("Unknown speech recognition authorization status")
            return false
        }
    }
    
    // MARK: - Content Download
    
    /// Checks video availability and initiates download if necessary.
    ///
    /// Verifies that all required videos are available locally, either launching the
    /// experience immediately or starting the ODR download process with progress UI.
    private func checkVideosAndProceed() {
        isChecking = false
        
        allVideosAvailable = requiredVideos.allSatisfy { tag in
            odrManager.isVideoAvailable(tag: tag)
        }
        
        videosChecked = true
        
        if allVideosAvailable {
            print("All videos already available")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Task {
                    await openImmersiveSpace(id: "ImmersiveSpace")
                    dismiss()
                }
            }
        } else {
            print(" Need to download videos")
            downloadVideos()
        }
    }
    
    /// Initiates video download with result handling.
    ///
    /// Requests batch download of all required videos through ODRManager,
    /// updating UI state based on success or failure.
    private func downloadVideos() {
        odrManager.downloadVideos(tags: requiredVideos) { result in
            switch result {
            case .success:
                print(" Download completed successfully")
                allVideosAvailable = true
            case .failure(let error):
                print(" Download failed: \(error)")
                downloadFailed = true
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
