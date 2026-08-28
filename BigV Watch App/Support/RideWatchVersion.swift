//
//  RideWatchVersion.swift
//  BigV Watch App
//

import Foundation

/// Marketing + build, read from this target's bundle so the glance can prove
/// which binary is actually on the wrist after a companion install.
nonisolated enum RideWatchVersion {

   static var label: String {
      let marketing = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
      let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
      return "\(marketing) (\(build))"
   }
}
