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

   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @State private var isShowingFullMap = false
   @State private var highlightedSplit: RideSplitID?
   @State private var isScrubbingLaps = false
   @State private var isLapsCollapsed = false
   @State private var viewportHeight: CGFloat = 0
   @State private var scrollPosition = ScrollPosition(edge: .top)

   var body: some View {
      ScrollView {
         VStack(spacing: 14) {
            RideDetailTrackSection(
               route: rideDetailViewModel.route,
               isLoaded: rideDetailViewModel.isLoaded,
               radarPasses: rideDetailViewModel.radarPasses,
               header: rideDetailViewModel.header,
               laps: rideDetailViewModel.laps,
               splitSegments: rideDetailViewModel.splitSegments,
               highlightedSplit: $highlightedSplit,
               isScrubbing: $isScrubbingLaps,
               isLapsCollapsed: $isLapsCollapsed,
               viewportHeight: viewportHeight,
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
      .scrollPosition($scrollPosition)
      .scrollDisabled(highlightedSplit != nil || isScrubbingLaps || isLapsCollapsed)
      .onScrollGeometryChange(for: CGFloat.self) { geometry in
         geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
      } action: { _, height in
         viewportHeight = height
      }
      .onChange(of: isLapsCollapsed) { _, isCollapsed in
         if isCollapsed {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.32)) {
               scrollPosition.scrollTo(edge: .top)
            }
         }
      }
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
            splitSegments: rideDetailViewModel.splitSegments,
            laps: rideDetailViewModel.laps,
            highlightedSplit: $highlightedSplit,
            isScrubbing: $isScrubbingLaps,
            isLapsCollapsed: $isLapsCollapsed
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
}
