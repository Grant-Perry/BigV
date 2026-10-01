//
//  RideSettingsRideToCard.swift
//  BigV
//

import SwiftUI

/// The RIDE TO section: where home is.
///
/// One row today, its own card on purpose — navigation preferences will grow,
/// and a home address filed under RIDING would be the first thing a rider
/// fails to find.
struct RideSettingsRideToCard: View {

   let routeHomeSettings: RouteHomeSettings
   let routeHomeAddressViewModel: RouteHomeAddressViewModel

   @State private var isShowingHomeSheet = false

   var body: some View {
      RideSettingsCard(title: "RIDE TO", footnote: footnote) {
         RideSettingsNavRow(
            title: "Home Address",
            detail: routeHomeSettings.homeLabel ?? "Not set",
            identifier: "settings.button.homeAddress"
         ) {
            isShowingHomeSheet = true
         }
      }
      .sheet(isPresented: $isShowingHomeSheet) {
         RouteHomeAddressSheet(routeHomeAddressViewModel: routeHomeAddressViewModel)
      }
   }

   private var footnote: String {
      routeHomeSettings.hasHome
         ? "The Home button on Ride To plans a bike route here from wherever you are."
         : "Set it once and Ride To gets a one-tap Home button."
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()

      RideSettingsRideToCard(
         routeHomeSettings: RouteHomeSettings(),
         routeHomeAddressViewModel: RouteHomeAddressViewModel()
      )
      .padding(16)
   }
   .preferredColorScheme(.dark)
}
