//
//  RideWeatherCurrentCard.swift
//  BigV
//

import MapKit
import SwiftUI

/// Current conditions over a map of where they were read. The place name is the
/// control that opens search, so the card answers "where" before "what".
struct RideWeatherCurrentCard: View {

   let weatherDetailModel: RideWeatherDetailModel
   let onChangeLocation: () -> Void

   var body: some View {
      ZStack(alignment: .topLeading) {
         mapUnderlay
         scrim

         VStack(alignment: .leading, spacing: 14) {
            locationHeader
            readout
         }
         .padding(18)
      }
      .frame(minHeight: 210)
      .clipShape(.rect(cornerRadius: RideDashboardTheme.cardRadius, style: .continuous))
      .overlay {
         RoundedRectangle(cornerRadius: RideDashboardTheme.cardRadius, style: .continuous)
            .strokeBorder(.white.opacity(0.14), lineWidth: 1)
      }
      .accessibilityElement(children: .contain)
   }

   // MARK: - Map

   /// Only drawn once a place has resolved. A map of nowhere in particular
   /// under the words "location unavailable" would be a lie.
   @ViewBuilder
   private var mapUnderlay: some View {
      if weatherDetailModel.hasPlace {
         Map(position: .constant(cameraPosition), interactionModes: []) {
            Annotation(weatherDetailModel.placeLabel, coordinate: weatherDetailModel.coordinate) {
               Image(systemName: "mappin.circle.fill")
                  .font(.title2)
                  .foregroundStyle(RideChromeTokens.halt)
                  .shadow(radius: 2)
            }
         }
         .mapStyle(.standard(elevation: .realistic))
         .allowsHitTesting(false)
         .accessibilityHidden(true)
      } else {
         RideDashboardTheme.graphite
      }
   }

   private var cameraPosition: MapCameraPosition {
      .region(
         MKCoordinateRegion(
            center: weatherDetailModel.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
         )
      )
   }

   /// The map is scenery, not information — the wash pushes it back far enough
   /// that the numerals stay legible over any terrain.
   private var scrim: some View {
      LinearGradient(
         colors: [
            .black.opacity(0.62),
            .black.opacity(0.32),
            RideDashboardTheme.midnight.opacity(0.55)
         ],
         startPoint: .topLeading,
         endPoint: .bottomTrailing
      )
      .allowsHitTesting(false)
   }

   // MARK: - Header

   private var locationHeader: some View {
      VStack(alignment: .leading, spacing: 6) {
         Button(action: onChangeLocation) {
            HStack(spacing: 6) {
               Text(weatherDetailModel.placeLabel)
                  .font(.title2.weight(.bold))
                  .foregroundStyle(.white)
                  .lineLimit(2)
                  .minimumScaleFactor(0.8)

               Image(systemName: "chevron.down")
                  .font(.caption.weight(.bold))
                  .foregroundStyle(.white.opacity(0.7))

               if weatherDetailModel.isFollowingDevice {
                  Image(systemName: "location.fill")
                     .font(.caption.weight(.semibold))
                     .foregroundStyle(RideChromeTokens.ice)
               }
            }
         }
         .buttonStyle(.plain)
         .accessibilityLabel("Change location")
         .accessibilityHint("Search for a city or postal code")

         if let condition = weatherDetailModel.current?.conditionLabel, !condition.isEmpty {
            Text(condition)
               .font(.subheadline.weight(.medium))
               .foregroundStyle(.white.opacity(0.82))
         }
      }
   }

   // MARK: - Readout

   @ViewBuilder
   private var readout: some View {
      if let current = weatherDetailModel.current {
         conditions(current)
      } else if weatherDetailModel.isLoading {
         ProgressView()
            .tint(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
      } else if let failureMessage = weatherDetailModel.failureMessage {
         Text(failureMessage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.vertical, 12)
      }
   }

   private func conditions(_ current: RideWeatherSnapshot) -> some View {
      HStack(alignment: .top, spacing: 12) {
         VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
               Text(
                  RideFormatters.temperatureNumber(
                     current.temperatureCelsius,
                     unit: weatherDetailModel.temperatureUnit
                  )
               )
               .font(.system(size: 56, weight: .thin))
               .monospacedDigit()
               .foregroundStyle(.white)

               Text(weatherDetailModel.temperatureUnit.suffix)
                  .font(.title3.weight(.light))
                  .foregroundStyle(.white.opacity(0.72))
            }

            highLow(for: current)

            if let feels = current.apparentTemperatureCelsius {
               Text("Feels like \(formatted(feels))")
                  .font(.subheadline.weight(.medium))
                  .foregroundStyle(.white.opacity(0.78))
            }
         }

         Spacer(minLength: 0)

         Image(systemName: current.symbolName)
            .font(.system(size: 68, weight: .thin))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white.opacity(0.92))
            .padding(.top, 4)
      }
   }

   @ViewBuilder
   private func highLow(for current: RideWeatherSnapshot) -> some View {
      let high = current.highCelsius ?? weatherDetailModel.today?.highCelsius
      let low = current.lowCelsius ?? weatherDetailModel.today?.lowCelsius

      if let high, let low {
         HStack(spacing: 6) {
            Text(formatted(low))
               .foregroundStyle(.white.opacity(0.62))

            Text(formatted(high))
               .fontWeight(.bold)
               .foregroundStyle(.white)
         }
         .font(.subheadline.monospacedDigit())
      }
   }

   private func formatted(_ celsius: Double) -> String {
      RideFormatters.temperature(celsius, unit: weatherDetailModel.temperatureUnit)
   }
}
