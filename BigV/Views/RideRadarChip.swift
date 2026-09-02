//
//  RideRadarChip.swift
//  BigV
//

import SwiftUI

/// The radar's seat on the status row: connection, battery, and a live threat
/// cue, mirroring `RideHeartRateChip`. Tapping it opens the pairing sheet.
struct RideRadarChip: View {

   let connection: RideRadarConnectionState
   let tier: RideRadarThreatTier?
   let nearestDistance: String?
   let battery: String?
   var isSelected: Bool = false
   let action: () -> Void

   var body: some View {
      Button(action: action) {
         RideSensorChip(
            value: readout,
            valueColor: readoutColor,
            tint: chromeTint ?? (isSelected ? RideDashboardTheme.ice.opacity(0.35) : nil)
         ) {
            Image(systemName: .radarIcon)
               .font(.caption.weight(.semibold))
               .foregroundStyle(iconColor)
               .symbolEffect(.pulse, isActive: tier == .high)
         }
      }
      .buttonStyle(.plain)
      .overlay {
         if isSelected {
            Capsule()
               .strokeBorder(RideDashboardTheme.ice.opacity(0.85), lineWidth: 2)
         }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Rear radar")
      .accessibilityValue(accessibilitySummary)
      .accessibilityAddTraits(isSelected ? [.isSelected] : [])
      .accessibilityIdentifier("ride.chip.radar")
   }

   // MARK: - Readout

   /// One glanceable token: nearest vehicle when the road is live, battery
   /// when it is clear, and the link state otherwise.
   private var readout: String {
      switch connection {
         case .connected:
            nearestDistance ?? battery ?? "OK"
         case .scanning, .connecting:
            "···"
         case .disconnected:
            "OFF"
      }
   }

   // MARK: - Palette

   private var iconColor: Color {
      guard connection.isConnected else { return RideDashboardTheme.ink(0.35) }

      return switch tier {
         case .high: RideDashboardTheme.halt
         case .approaching: RideDashboardTheme.amber
         case nil: RideDashboardTheme.ice
      }
   }

   private var readoutColor: Color {
      guard connection.isConnected else { return RideDashboardTheme.ink(0.4) }

      return switch tier {
         case .high: RideDashboardTheme.halt
         case .approaching: RideDashboardTheme.amber
         case nil: RideDashboardTheme.ink(0.85)
      }
   }

   /// The chrome itself warms up under threat, so the cue survives peripheral
   /// vision even when the numerals are too small to read.
   private var chromeTint: Color? {
      switch tier {
         case .high: RideDashboardTheme.halt.opacity(0.35)
         case .approaching: RideDashboardTheme.amber.opacity(0.25)
         case nil: nil
      }
   }

   // MARK: - Accessibility

   private var accessibilitySummary: String {
      switch connection {
         case .connected:
            if let nearestDistance {
               "Vehicle \(nearestDistance) behind"
            } else {
               "Connected, road clear"
            }
         case .scanning: "Searching for radar"
         case .connecting: "Connecting"
         case .disconnected: "Disconnected"
      }
   }
}

private extension String {
   static let radarIcon = "car.rear.waves.up"
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      VStack(spacing: 12) {
         RideRadarChip(
            connection: .connected, tier: nil, nearestDistance: nil, battery: "87%"
         ) {}
         RideRadarChip(
            connection: .connected, tier: .approaching, nearestDistance: "42 m", battery: "87%"
         ) {}
         RideRadarChip(
            connection: .connected, tier: .high, nearestDistance: "18 m", battery: "87%"
         ) {}
         RideRadarChip(
            connection: .disconnected, tier: nil, nearestDistance: nil, battery: nil
         ) {}
      }
      .padding()
   }
}
