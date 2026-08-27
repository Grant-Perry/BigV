//
//  RouteErrorClassifier.swift
//  BigV
//

import Foundation

/// Reads network intent out of the errors MapKit surfaces.
///
/// Search and routing both need to tell "the rider has no signal" apart from
/// "the service answered and said no", and a rider halfway up a canyon hits the
/// first case constantly. MapKit reports no reachability of its own — it either
/// hands back a URL error or buries one under an `MKError` — so the unwrapping
/// lives here rather than twice.
enum RouteErrorClassifier {

   // MARK: - Reachability

   static func isOffline(_ error: any Error) -> Bool {
      let nsError = error as NSError

      if isOfflineURLError(nsError) { return true }
      return nsError.underlyingErrors.contains(where: isOfflineURLError)
   }

   // MARK: - URL Errors

   private static func isOfflineURLError(_ error: any Error) -> Bool {
      let nsError = error as NSError
      guard nsError.domain == NSURLErrorDomain else { return false }
      return offlineCodes.contains(nsError.code)
   }

   private static let offlineCodes: Set<Int> = Set(
      [
         URLError.Code.notConnectedToInternet,
         .networkConnectionLost,
         .cannotFindHost,
         .cannotConnectToHost,
         .dnsLookupFailed,
         .timedOut,
         .dataNotAllowed,
         .internationalRoamingOff
      ].map(\.rawValue)
   )
}
