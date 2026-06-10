//
//  ACI_Experience_MotorsportApp.swift
//  ACI Experience Motorsport
//

import SwiftUI
import SwiftData
import RealityKit

/// The main entry point of the application.
///
/// This app coordinates:
/// - Window-based UI (`ContentView` / `DebugContentView`)
/// - Immersive spatial experience (`ImmersiveSpace`)
/// - Supporting systems such as persistence, input, and styling
///
/// It also manages shared state objects and dependency injection across scenes.
@main
struct ACI_Experience_MotorsportApp: App {

    // MARK: - State Objects

    /// Manages visual styling and surroundings effects in immersive space.
    @StateObject private var styleManager = StyleManager()

    /// Handles game controller connections and input.
    @StateObject private var gameControllerManager = GameControllerManager()

    /// Global application state shared across views.
    @State private var appModel = AppModel()

    /// Handles voice recording and transcription input.
    @State private var voiceInput = Recorder(transcriber: SpokenWordTranscriber())

    // MARK: - Persistent Settings

    /// Controls whether full-scale car models are enabled in the immersive experience.
    @AppStorage("isFullScaleCarEnabled") private var isFullScaleCarEnabled = true

    // MARK: - Debug Configuration

    /// Enables debug UI and behaviors.
    private var isDebugMode: Bool = false

    /// Allows skipping video playback during debugging.
    private var skipVideoEnabled = true

    // MARK: - Persistence

    /// SwiftData container used for storing scene anchors and persistent data.
    let modelContainer: ModelContainer

    /// Manages placement and retrieval of persisted scene anchors.
    let placementManager: ScenePlacementManager?

    // MARK: - Initialization

    /// Initializes the app, setting up:
    /// - RealityKit runtime components
    /// - File system directories
    /// - SwiftData container and placement manager
    init() {
        YAxisBillboardRuntime.register()
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        if !FileManager.default.fileExists(atPath: appSupport.path) {
            try? FileManager.default.createDirectory(
                at: appSupport,
                withIntermediateDirectories: true
            )
        }

        do {
            let container = try ModelContainer(for: PersistedSceneAnchor.self)
            self.modelContainer = container
            self.placementManager = ScenePlacementManager(
                context: container.mainContext
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    // MARK: - Scene Configuration

    var body: some SwiftUI.Scene {

        // MARK: Entry Window

        /// Main application window.
        ///
        /// Displays either:
        /// - `ContentView` (production)
        /// - `DebugContentView` (debug mode)
        WindowGroup(id: "ContentView") {
            Group {
                if !isDebugMode {
                    ContentView()
                        .environment(appModel)
                } else {
                    DebugContentView()
                        .environment(appModel)
                }
            }
            .environmentObject(gameControllerManager)
            .modelContainer(modelContainer)
        }
        .persistentSystemOverlays(.hidden)
        .windowStyle(.plain)
        .defaultSize(CGSize(width: 900, height: 900))

        // MARK: Immersive Space

        /// The immersive spatial experience.
        ///
        /// Hosts the main 3D/RealityKit content and injects:
        /// - Placement manager for persisted anchors
        /// - Styling and surroundings configuration
        /// - Input systems (controller + voice)
        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView(
                placementManager: placementManager,
                isFullScaleCarsActive: isFullScaleCarEnabled,
                isDebugMode: isDebugMode,
                skipVideoEnabled: skipVideoEnabled
            )
            .preferredSurroundingsEffect(
                styleManager.currentSourroundingEffect
            )
            .environmentObject(styleManager)
            .environmentObject(gameControllerManager)
            .environment(appModel)
            .environment(voiceInput)
            .modelContainer(modelContainer)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .upperLimbVisibility(.visible)

        // MARK: Control Panel

        /// Secondary floating window used for video controls.
        WindowGroup(id: "ControlVideo") {
            VideoUIControls()
                .environment(appModel)
        }
        .persistentSystemOverlays(.hidden)
        .windowStyle(.plain)
        .defaultSize(CGSize(width: 400, height: 100))
        .defaultWindowPlacement { _, _ in
            .init(.utilityPanel)
        }
    }
}
