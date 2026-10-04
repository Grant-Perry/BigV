//
//  RideWeatherDetailSheet.swift
//  BigV
//

import SwiftUI

/// The full forecast: conditions over a map, the hours ahead, precipitation and
/// the sun. System navigation chrome on top, gradient-wash content cards below.
struct RideWeatherDetailSheet: View {

   let rideWeatherModel: RideWeatherModel

   @Environment(\.dismiss) private var dismiss
   @State private var weatherDetailModel: RideWeatherDetailModel
   @State private var isShowingLocationSearch = false

   init(rideWeatherModel: RideWeatherModel) {
      self.rideWeatherModel = rideWeatherModel
      _weatherDetailModel = State(
         initialValue: RideWeatherDetailModel(weatherModel: rideWeatherModel)
      )
   }

   var body: some View {
      NavigationStack {
         forecastScroll
            // A background rather than a ZStack sibling: a full-bleed layer
            // inside a stack inflates the stack past the safe area and the
            // scroll view loses its navigation-bar inset.
            .background {
               RideAtmosphereBackground()
                  .ignoresSafeArea()
            }
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { forecastToolbar }
      }
      .rideAppearance()
      .task { await weatherDetailModel.load() }
      .sheet(isPresented: $isShowingLocationSearch) {
         RideWeatherLocationSearchView { coordinate, label, timeZone in
            Task {
               await weatherDetailModel.selectPlace(
                  coordinate: coordinate,
                  label: label,
                  timeZone: timeZone
               )
            }
         }
      }
   }

   // MARK: - Content

   private var forecastScroll: some View {
      ScrollView {
         LazyVStack(alignment: .leading, spacing: 12) {
            RideWeatherCurrentCard(weatherDetailModel: weatherDetailModel) {
               isShowingLocationSearch = true
            }

            RideWeatherForecastCard(
               hours: weatherDetailModel.precipOutlook.hours,
               daily: weatherDetailModel.daily,
               unit: weatherDetailModel.temperatureUnit,
               timeZone: weatherDetailModel.timeZone
            )

            if !weatherDetailModel.precipOutlook.isEmpty {
               RideWeatherPrecipCard(
                  outlook: weatherDetailModel.precipOutlook,
                  timeZone: weatherDetailModel.timeZone
               )
            }

            RideWeatherSunCard(today: weatherDetailModel.today, timeZone: weatherDetailModel.timeZone)

            RideWeatherAttributionLabel(url: weatherDetailModel.attributionURL)
               .frame(maxWidth: .infinity, alignment: .center)
               .padding(.top, 4)
               .padding(.bottom, 12)
         }
         .padding(.horizontal, 16)
         .padding(.vertical, 12)
      }
      .scrollIndicators(.hidden)
   }

   // MARK: - Toolbar

   @ToolbarContentBuilder
   private var forecastToolbar: some ToolbarContent {
      ToolbarItem(placement: .cancellationAction) {
         Button("Done", role: .cancel) { dismiss() }
            .accessibilityIdentifier("weather.button.done")
      }

      ToolbarItemGroup(placement: .primaryAction) {
         if weatherDetailModel.canUseCurrentLocation {
            Button {
               Task { await weatherDetailModel.useCurrentLocation() }
            } label: {
               Image(systemName: .locateIcon)
            }
            .accessibilityLabel("Use my location")
            .accessibilityHint("Shows weather where you are now")
         }

         Button {
            isShowingLocationSearch = true
         } label: {
            Image(systemName: .searchIcon)
         }
         .accessibilityLabel("Change location")
         .accessibilityIdentifier("weather.button.search")
      }
   }
}

private extension String {
   static let locateIcon = "location"
   static let searchIcon = "magnifyingglass"
}
