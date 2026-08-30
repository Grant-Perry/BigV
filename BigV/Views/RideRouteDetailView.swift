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

   var body: some View {
      ScrollView {
         VStack(spacing: 14) {
            mapSection

            if let header = rideDetailViewModel.header {
               RideDetailHeroCard(header: header)
                  .detailCardEntrance()
            }

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
      .background {
         RideAtmosphereBackground(scene: .summary)
            .ignoresSafeArea()
      }
      .rideAppFooter()
      .navigationTitle(rideDetailViewModel.titleText)
      .navigationBarTitleDisplayMode(.inline)
      .fullScreenCover(isPresented: $isShowingFullMap) {
         RideDetailFullMapView(
            route: rideDetailViewModel.route,
            radarPasses: rideDetailViewModel.radarPasses,
            titleText: rideDetailViewModel.titleText
         )
      }
      .task(id: rideID) { await rideDetailViewModel.load(rideID) }
      .onDisappear { rideDetailViewModel.clear() }
   }

   // MARK: - Map

   /// The inline map is a preview, not a playground: one tap opens the full
   /// screen where every gesture works, so the scroll never fights a pan.
   private var mapSection: some View {
      RideRouteMapView(
         route: rideDetailViewModel.route,
         isLoaded: rideDetailViewModel.isLoaded,
         height: 300,
         radarPasses: rideDetailViewModel.radarPasses
      )
      .overlay {
         if rideDetailViewModel.route.isDrawable {
            Color.clear
               .contentShape(.rect)
               .onTapGesture { isShowingFullMap = true }
         }
      }
      .overlay(alignment: .topLeading) {
         if rideDetailViewModel.route.isDrawable {
            RideRouteMapLegend(showsVehicles: !rideDetailViewModel.radarPasses.isEmpty)
               .padding(10)
               .allowsHitTesting(false)
         }
      }
      .overlay(alignment: .bottomTrailing) {
         if rideDetailViewModel.route.isDrawable {
            expandHint
         }
      }
      .accessibilityAddTraits(rideDetailViewModel.route.isDrawable ? .isButton : [])
      .accessibilityHint("Opens the route at full screen")
      .accessibilityIdentifier("detail.map")
   }

   private var expandHint: some View {
      Image(systemName: "arrow.up.left.and.arrow.down.right")
         .font(.caption.weight(.bold))
         .foregroundStyle(.white)
         .frame(width: 32, height: 32)
         .rideGlassChrome(in: .circle)
         .padding(10)
         .allowsHitTesting(false)
   }
}

// MARK: - Entrance

private extension View {

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
