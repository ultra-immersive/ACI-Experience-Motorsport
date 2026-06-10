import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

/// Debug ContentView for modules --- No AI involved
struct DebugContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    @StateObject private var odrManager = ODRManager.shared
    
    @State private var authorizationFailed = false
    @State private var isChecking = true
    @State private var videosChecked = false
    @State private var allVideosAvailable = false
    @State private var downloadFailed = false
    @State private var isContentViewActive: Bool = false
    
    @State private var selectedModules: Set<Module> = []
    @State private var selectedEpoch: Epoch = .laFormazionePiloti
    
    private let requiredVideos: [ODRManager.VideoTag] = ODRManager.VideoTag.allCases
    
    enum Module: String, CaseIterable, Identifiable {
        case A1, B, C, D
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            default: return self.rawValue
            }
        }
        
        /// Convert to ModuleType
        var moduleType: ModuleType {
            switch self {
            case .A1: return .A1
            case .B: return .B
            case .C: return .C
            case .D: return .D
            }
        }
        
        /// Check if this module is available for the given epoch
        func isAvailable(for epoch: Epoch) -> Bool {
            let availableModules = AppModel.modules(for: epoch)
            return availableModules.contains(moduleType)
        }
    }
    
    /// Modules available for the currently selected epoch
    private var availableModulesForEpoch: Set<Module> {
        Set(Module.allCases.filter { $0.isAvailable(for: selectedEpoch) })
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if authorizationFailed {
                authorizationFailedView
            } else if !videosChecked {
                // Loading state - checking videos
                ProgressView("Checking videos...")
                    .font(.title2)
            } else if odrManager.isDownloading {
                // Downloading videos
                downloadingView
            } else if downloadFailed {
                // Download failed
                downloadFailedView
            } else if allVideosAvailable && isChecking {
                // Videos ready, show configuration
                configurationView
            } else {
                Text("Ready")
            }
        }
        .padding()
        .glassBackgroundEffect()
        .onAppear {
            selectedEpoch = .laFormazionePiloti
            // Initialize selected modules with available ones for default epoch
            selectedModules = availableModulesForEpoch
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if isContentViewActive {
                    print("CHECKING AUTHORIZATION AND VIDEOS (Debug)")
                    Task {
                        await checkAuthorization()
                    }
                }
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
        .onChange(of: selectedEpoch) { _, _ in
            // Select all available modules for the new epoch
            selectedModules = availableModulesForEpoch
        }
    }
    
    private var authorizationFailedView: some View {
        VStack(spacing: 16) {
            Text("Hand tracking permission is required")
                .font(.title2)
            
            Text("Please enable hand tracking in Settings")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Button("Open Settings") {
                if let url = URL(string: "App-prefs:") {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Check Again") {
                Task {
                    await checkAuthorization()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private var downloadingView: some View {
        VStack(spacing: 20) {
            Text("Downloading Videos")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Please wait while we download the spatial videos for your experience.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            ProgressView(value: odrManager.downloadProgress) {
                Text("\(Int(odrManager.downloadProgress * 100))%")
                    .font(.headline)
            }
            .progressViewStyle(LinearProgressViewStyle())
            .frame(width: 400)
            
            Text("This may take a few minutes depending on your connection.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 600)
    }
    
    private var downloadFailedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Download Failed")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let error = odrManager.downloadError {
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Retry Download") {
                downloadFailed = false
                downloadVideos()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .frame(width: 600)
    }
    
    private var configurationView: some View {
        VStack(spacing: 24) {
            Text("Debug Configuration")
                .font(.largeTitle)
                .padding(.bottom)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Time Period")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Picker("Epoch", selection: $selectedEpoch) {
                    ForEach(Epoch.allCases) { epoch in
                        Text(epoch.displayName).tag(epoch)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 300)
            }
            
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Available Modules")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Selected: \(selectedModules.isEmpty ? "None" : selectedModules.map(\.displayName).sorted().joined(separator: " + "))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                    ForEach(Module.allCases) { module in
                        let isAvailable = module.isAvailable(for: selectedEpoch)
                        
                        Toggle(isOn: Binding(
                            get: { selectedModules.contains(module) },
                            set: { isSelected in
                                if isSelected {
                                    selectedModules.insert(module)
                                } else {
                                    selectedModules.remove(module)
                                }
                            }
                        )) {
                            Text(module.displayName)
                                .font(.body)
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                        .disabled(!isAvailable)
                        .opacity(isAvailable ? 1.0 : 0.5)
                    }
                }
                
                HStack {
                    Button("Select All") {
                        selectedModules = availableModulesForEpoch
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Clear All") {
                        selectedModules.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption)
            }
            
            Spacer()
            
            // Info about selected configuration
            VStack(spacing: 4) {
                if selectedEpoch != .all {
                    Text("Epoch: \(selectedEpoch.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
            }
            .padding(.horizontal)
            
            // Launch button
            Button {
                Task {
                    appModel.selectedEpoch = selectedEpoch
                    appModel.availableModules = Array(selectedModules).map { $0.moduleType }
                    
                    
                    print(" Launching with epoch: \(appModel.selectedEpoch.displayName)")
                    
                    await openImmersiveSpaceAndDismiss()
                }
            } label: {
                Label("Enter Immersive Space", systemImage: "visionpro")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedModules.isEmpty)
        }
        .padding(30)
        .frame(width: 500, height: 750)
    }
    
    private func checkAuthorization() async {
        isChecking = true
        authorizationFailed = false
        
#if targetEnvironment(simulator)
        // Skip authorization on simulator
        checkVideosAndProceed()
#else
        let session = ARKitSession()
        let handTrackingProvider = HandTrackingProvider()
        
        let authorizationStatus = await session.queryAuthorization(for: [.handTracking])
        
        switch authorizationStatus[.handTracking] {
        case .allowed:
            print("Hand tracking already authorized (Debug)")
            checkVideosAndProceed()
            
        case .denied:
            print(" Hand tracking denied by user (Debug)")
            isChecking = false
            authorizationFailed = true
            
        case .notDetermined:
            do {
                try await session.run([handTrackingProvider])
                print(" Hand tracking authorized (Debug)")
                session.stop()
                checkVideosAndProceed()
            } catch {
                print(" Hand tracking authorization failed: \(error.localizedDescription) (Debug)")
                isChecking = false
                authorizationFailed = true
            }
            
        @unknown default:
            print(" Unknown authorization status (Debug)")
            isChecking = false
            authorizationFailed = true
        }
#endif
    }
    
    private func checkVideosAndProceed() {
        allVideosAvailable = requiredVideos.allSatisfy { tag in
            odrManager.isVideoAvailable(tag: tag)
        }
        
        videosChecked = true
        
        if allVideosAvailable {
            print(" All videos already available (Debug)")
        } else {
            print(" Need to download videos (Debug)")
            downloadVideos()
        }
    }
    
    private func downloadVideos() {
        odrManager.downloadVideos(tags: requiredVideos) { result in
            switch result {
            case .success:
                print(" Download completed successfully (Debug)")
                allVideosAvailable = true
            case .failure(let error):
                print(" Download failed: \(error) (Debug)")
                downloadFailed = true
            }
        }
    }
    
    private func openImmersiveSpaceAndDismiss() async {
        await openImmersiveSpace(id: "ImmersiveSpace")
        dismiss()
    }
}

#Preview(windowStyle: .automatic) {
    DebugContentView()
        .environment(AppModel())
}
