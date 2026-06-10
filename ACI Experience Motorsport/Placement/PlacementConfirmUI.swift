//
//  PlacementConfirmUI.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 09/03/26.
//


import SwiftUI

/// Floating UI shown during placement mode with controller instructions.
///
/// Attached as a RealityView `Attachment` with id `"PlacementConfirm"`.
/// It displays the same style instructions as La Dolce Vita, adapted for
/// ACI Motorsport's controller mapping.
struct PlacementConfirmUI: View {
    /// Whether a valid surface has been found for placement.
    var surfaceFound: Bool

    /// The name of the connected controller (e.g. "DualSense", "Xbox Wireless Controller").
    var controllerName: String

    /// Whether a controller is connected.
    var controllerConnected: Bool

    var body: some View {
        VStack(spacing: 16) {
            if !controllerConnected {
                // No controller connected
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse)

                    Text("Controller non connesso")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Collega un controller per posizionare la scena")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else if !surfaceFound {
                // Searching for surfaces
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text("Cercando superfici...")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("Guarda intorno per rilevare il pavimento")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            } else {
                // Ready to place
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, options: .repeating.speed(0.5))

                    Text("Posiziona la scena")
                        .font(.title2)
                        .fontWeight(.semibold)

                    // Controller instructions
                    VStack(alignment: .leading, spacing: 8) {
                        controllerInstruction(
                            icon: "arrow.trianglehead.counterclockwise",
                            text: isDualSense
                                ? "Premi **R1** per aggiornare la posizione della sedia"
                                : "Premi **RB** per aggiornare la posizione della sedia"
                        )
                        
                        controllerInstruction(
                            icon: "square.stack",
                            text: "Premi il **grilletto destro** per posizionare la scena"
                        )

                        controllerInstruction(
                            icon: isDualSense ? "arrowtriangle.up.square" : "y.square",
                            text: isDualSense
                                ? "Tieni premuto **Triangolo** per resettare la configurazione"
                                : "Tieni premuto **Y** per resettare la configurazione"
                        )
                        
                        
                    }
                    .font(.subheadline)
                }
            }
        }
        .frame(width: 600)
        .padding(24)
        .glassBackgroundEffect()
    }

    // MARK: - Helpers

    private var isDualSense: Bool {
        controllerName == "DualSense"
    }

    private func controllerInstruction(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .symbolEffect(.breathe.pulse)
                .frame(width: 30)

            Text(.init(text)) 
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Staff Reset Button (for debug panel)

/// Staff-accessible button to reset the scene position only (keeps staff config).
struct ResetPlacementButton: View {
    var onReset: () -> Void

    var body: some View {
        Button(action: onReset) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                Text("Riposiziona Scena")
            }
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(.orange)
    }
}
