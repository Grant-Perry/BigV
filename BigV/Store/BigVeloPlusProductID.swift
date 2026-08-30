//
//  BigVeloPlusProductID.swift
//  BigV
//

import Foundation

/// Product IDs locked to App Store Connect and `BigVelo.storekit`.
enum BigVeloPlusProductID: String, CaseIterable, Identifiable, Sendable {
   case monthly = "bigvelo.plus.monthly"
   case yearly = "bigvelo.plus.yearly"
   case lifetime = "bigvelo.plus.lifetime"

   var id: String { rawValue }

   var isSubscription: Bool {
      switch self {
         case .monthly, .yearly: true
         case .lifetime: false
      }
   }
}
