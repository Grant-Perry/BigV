//
//  RideRouteMapMark.swift
//  BigV
//

import SwiftUI

/// Marks a saved-route map can draw. Shape carries the meaning; colour only
/// reinforces it, so finish and a fast pass can never be the same red circle.
/// A highlighted split uses a filled disc at its start and a ring at its end.
struct RideRouteMapMark: View {

   enum Kind {
      case start
      case finish
      case vehiclePass
      case fastPass
      case splitStart
      case splitEnd
   }

   enum Role {
      case map
      case legend
   }

   let kind: Kind
   var role: Role = .map
   var tint: Color = RideDashboardTheme.ice

   var body: some View {
      switch kind {
         case .start: startMark
         case .finish: finishMark
         case .vehiclePass: vehicleMark
         case .fastPass: fastMark
         case .splitStart: splitStartMark
         case .splitEnd: splitEndMark
      }
   }

   // MARK: - Start

   private var startMark: some View {
      Circle()
         .fill(Color.green)
         .stroke(.black, lineWidth: role == .map ? 2 : 0)
         .frame(width: role == .map ? 12 : 6, height: role == .map ? 12 : 6)
   }

   // MARK: - Finish

   /// Checkered, never red — red belongs to the fast-pass diamond.
   private var finishMark: some View {
      Image(systemName: "flag.checkered")
         .font(.system(size: role == .map ? 11 : 8, weight: .bold))
         .foregroundStyle(.white)
         .frame(width: role == .map ? 20 : 10, height: role == .map ? 20 : 10)
         .background(.black.opacity(role == .map ? 0.72 : 0.55), in: .circle)
   }

   // MARK: - Passes

   private var vehicleMark: some View {
      Circle()
         .fill(RideDashboardTheme.amber)
         .stroke(.black.opacity(role == .map ? 0.6 : 0), lineWidth: 1)
         .frame(width: passSize, height: passSize)
   }

   /// Rotated square, same cue as the live tape and the Watch strip.
   private var fastMark: some View {
      Rectangle()
         .fill(RideDashboardTheme.halt)
         .stroke(.black.opacity(role == .map ? 0.6 : 0), lineWidth: 1)
         .frame(width: passSize, height: passSize)
         .rotationEffect(.degrees(45))
         .frame(width: passSize + 3, height: passSize + 3)
   }

   private var passSize: CGFloat {
      role == .map ? 7 : 6
   }

   // MARK: - Split

   /// Filled disc — the start of the highlighted lap or climb.
   private var splitStartMark: some View {
      Circle()
         .fill(tint)
         .stroke(.black.opacity(role == .map ? 0.7 : 0), lineWidth: 1.5)
         .frame(width: splitSize, height: splitSize)
   }

   /// Hollow ring — the end, so start and finish stay distinct without colour.
   private var splitEndMark: some View {
      Circle()
         .strokeBorder(tint, lineWidth: role == .map ? 2.5 : 1.5)
         .background(.black.opacity(role == .map ? 0.55 : 0.4), in: .circle)
         .frame(width: splitSize, height: splitSize)
   }

   private var splitSize: CGFloat {
      role == .map ? 10 : 6
   }
}
