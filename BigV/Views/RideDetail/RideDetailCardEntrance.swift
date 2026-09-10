//
//  RideDetailCardEntrance.swift
//  BigV
//

import SwiftUI

extension View {

   /// Cards ease in as they enter the viewport, so scrolling the report feels
   /// like instruments coming online rather than a list loading.
   func detailCardEntrance() -> some View {
      scrollTransition(.animated(.easeOut(duration: 0.25)), axis: .vertical) { content, phase in
         content
            .opacity(phase.isIdentity ? 1 : 0.35)
            .scaleEffect(phase.isIdentity ? 1 : 0.97)
      }
   }
}
