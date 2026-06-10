//
//  StaffConfigView.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 26/02/26.
//

import SwiftUI

/// One-time staff configuration view for setting full-scale car mode.
///
/// Displayed before the first experience launch. Once configured, the choice
/// persists via UserDefaults and this view is never shown again.
struct StaffConfigView: View {
    @AppStorage("isFullScaleCarEnabled") private var isFullScaleCarEnabled = true
    @State private var selection: Bool = true
    
    var onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 55) {
            VStack(spacing: 14) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 68))
                    .foregroundStyle(.blue)
                
                Text("Staff Configuration")
                    .font(.system(size: 44))
                    .fontWeight(.bold)
                
                Text("This setting is saved and won't be asked again")
                    .font(.system(size: 21))
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 27) {
                Text("Enable full-scale car model?")
                    .font(.system(size: 29, weight: .semibold))
                
                HStack(spacing: 34) {
                    configOption(
                        title: "Full Scale",
                        subtitle: "1:1 car model",
                        icon: "car.fill",
                        isSelected: selection == true
                    ) {
                        selection = true
                    }
                    .padding()

                    Spacer()
                    configOption(
                        title: "Reduced",
                        subtitle: "Small car model",
                        icon: "car.side",
                        isSelected: selection == false
                    ) {
                        selection = false
                    }
                    .padding()
                }
            }
            
            Button {
                isFullScaleCarEnabled = selection
                onConfirm()
            } label: {
                HStack(spacing: 8) {
                    Text("Confirm & Continue")
                    Image(systemName: "arrow.right.circle.fill")
                }
                .font(.system(size: 29, weight: .semibold))
                .padding(.horizontal, 55)
                .padding(.vertical, 23)
            }
            
        }
        .padding(68)
        .glassBackgroundEffect()
    }
    
    struct GlassButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .frame(width: 237, height: 203)
                .glassBackgroundEffect()
                .clipShape(RoundedRectangle(cornerRadius: 61))
                .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 61))
                .overlay(RoundedRectangle(cornerRadius: 61).stroke(configuration.isPressed ? Color.green : Color.gray, lineWidth: 2)) // for debugging
        }
    }
    
    private func configOption(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 21) {
                Image(systemName: icon)
                    .font(.system(size: 55))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                
                VStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                    Text(subtitle)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .opacity(isSelected ? 0.75 : 1.0)
                }
            }
            .frame(width: 237, height: 203)

        }
        .hoverEffect(.automatic)
        .buttonStyle(GlassButtonStyle())
        .clipShape(RoundedRectangle(cornerRadius: 61))
    }
}

#Preview(immersionStyle: .mixed) {
    StaffConfigView(onConfirm: {print("test")})
}
