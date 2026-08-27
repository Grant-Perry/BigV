//
//  RideRouteMapView.swift
//  BigV
//

import MapKit
import SwiftUI

/// A finished route framed by its own bounds, for the summary and saved rides.
///
/// The camera is set once from the route's precomputed region rather than tracking
/// anything, so this view does no work after it appears.
struct RideRouteMapView: View {

   let route: RideRoute
   var isLoaded: Bool = true
   var height: CGFloat = 220

   var body: some View {
      Group {
         if let region = route.region, route.isDrawable {
            map(framing: region)
         } else {
            placeholder
         }
      }
      .frame(height: height)
      .clipShape(.rect(cornerRadius: 16))
   }

   // MARK: - Map

   private func map(framing region: MKCoordinateRegion) -> some View {
      Map(initialPosition: .region(region), interactionModes: [.pan, .zoom]) {
         MapPolyline(coordinates: route.coordinates)
            .stroke(.cyan, style: .routeLine)

         if let start = route.startCoordinate {
            endpoint(at: start, label: "Ride start", tint: .green)
         }

         if let end = route.endCoordinate {
            endpoint(at: end, label: "Ride finish", tint: .red)
         }
      }
      .mapStyle(.rideRoute)
      .accessibilityLabel("Route map")
   }

   private func endpoint(
      at coordinate: CLLocationCoordinate2D,
      label: String,
      tint: Color
   ) -> some MapContent {
      Annotation(label, coordinate: coordinate, anchor: .center) {
         Circle()
            .fill(tint)
            .stroke(.black, lineWidth: 2)
            .frame(width: 12, height: 12)
      }
      .annotationTitles(.hidden)
   }

   // MARK: - Empty State

   /// Stays wordless until the load resolves, so a ride still being finalized is
   /// never told it has no route.
   private var placeholder: some View {
      VStack(spacing: 6) {
         Image(systemName: .noRouteIcon)
            .font(.title3.weight(.semibold))

         if isLoaded {
            Text("No route recorded")
               .font(.caption.weight(.medium))
         }
      }
      .foregroundStyle(.white.opacity(0.4))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Self.wash)
   }

   private static let wash = LinearGradient(
      colors: [.white.opacity(0.10), .white.opacity(0.03)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
   )
}

// MARK: - Shared Map Styling

extension MapStyle {

   /// Flat, muted and free of points of interest: the route is the only thing on
   /// this map worth looking at, and a 3D basemap is battery the ride needs.
   static let rideRoute = MapStyle.standard(
      elevation: .flat,
      emphasis: .muted,
      pointsOfInterest: .excludingAll,
      showsTraffic: false
   )
}

extension StrokeStyle {

   static let routeLine = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
}

// MARK: - Icons

private extension String {
   static let noRouteIcon = "map"
}

#Preview {
   ZStack {
      Color.black
      RideRouteMapView(route: .empty)
         .padding()
   }
   .preferredColorScheme(.dark)
}
