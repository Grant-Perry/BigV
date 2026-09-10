//
//  RideRouteDetailView.swift
//  BigV
//

import SwiftData
import SwiftUI

/// One saved ride, told as a full story: the route, the headline numbers, the
/// terrain, the effort, the sky and the traffic.
///
/// Every section renders only when its ride actually has the data, so an old
/// ride shows exactly what it recorded and nothing apologizes for being empty.
struct RideRouteDetailView: View {

   let rideDetailViewModel: RideDetailViewModel
   let rideID: PersistentIdentifier

   @State private var isShowingFullMap = false
   @State private var highlightedSplit: RideSplitID?
   @State private var isScrubbingLaps = false

   var body: some View {
      ScrollView {
         VStack(spacing: 14) {
            RideDetailTrackSection(
               route: rideDetailViewModel.route,
               isLoaded: rideDetailViewModel.isLoaded,
               radarPasses: rideDetailViewModel.radarPasses,
               header: rideDetailViewModel.header,
               laps: rideDetailViewModel.laps,
               highlight: mapHighlight,
               highlightedSplit: $highlightedSplit,
               isScrubbing: $isScrubbingLaps,
               onExpandMap: { isShowingFullMap = true }
            )

            if let elevation = rideDetailViewModel.elevation {
               RideElevationCard(report: elevation)
                  .detailCardEntrance()
            }

            if let speed = rideDetailViewModel.speed {
               RideSpeedCard(report: speed)
                  .detailCardEntrance()
            }

            if let heartRate = rideDetailViewModel.heartRate {
               RideHeartRateCard(report: heartRate)
                  .detailCardEntrance()
            }

            if let weather = rideDetailViewModel.weather {
               RideWeatherConditionsCard(report: weather)
                  .detailCardEntrance()
            }

            if let radar = rideDetailViewModel.radar {
               RideRadarTrafficCard(report: radar)
                  .detailCardEntrance()
            }
         }
         .padding(.horizontal, 16)
         .padding(.top, 12)
         .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
      .scrollDisabled(highlightedSplit != nil || isScrubbingLaps)
      .background {
         RideAtmosphereBackground(scene: .summary)
            .ignoresSafeArea()
      }
      .rideAppFooter()
      .navigationTitle(rideDetailViewModel.titleText)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
         if let url = rideDetailViewModel.gpxShareURL {
            ShareLink(
               item: url,
               preview: SharePreview(
                  url.lastPathComponent,
                  image: Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
               )
            ) {
               Image(systemName: "square.and.arrow.up")
            }
            .accessibilityIdentifier("detail.button.exportGPX")
            .accessibilityLabel("Export GPX")
         }
      }
      .fullScreenCover(isPresented: $isShowingFullMap) {
         RideDetailFullMapView(
            route: rideDetailViewModel.route,
            radarPasses: rideDetailViewModel.radarPasses,
            titleText: rideDetailViewModel.titleText,
            highlight: mapHighlight,
            laps: rideDetailViewModel.laps,
            highlightedSplit: $highlightedSplit,
            isScrubbing: $isScrubbingLaps
         )
      }
      .task(id: rideID) {
         highlightedSplit = nil
         isScrubbingLaps = false
         await rideDetailViewModel.load(rideID)
      }
      .onDisappear {
         highlightedSplit = nil
         rideDetailViewModel.clear()
      }
   }

   // MARK: - Highlight

   private var mapHighlight: RideRouteMapHighlight? {
      guard let id = highlightedSplit,
            let segment = rideDetailViewModel.splitSegments.first(where: { $0.id == id })
      else { return nil }
      let built = RideRouteMapHighlight(segment: segment)
      return built.route.isDrawable ? built : nil
   }
}
