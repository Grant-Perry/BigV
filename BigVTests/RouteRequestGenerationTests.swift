//
//  RouteRequestGenerationTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

@MainActor
struct RouteRequestGenerationTests {

   // MARK: - Issuing

   @Test func theFirstTicketIssuedIsTheCurrentOne() {
      var generation = RouteRequestGeneration()
      let ticket = generation.issue()

      #expect(generation.isCurrent(ticket))
   }

   @Test func issuingAgainRetiresTheTicketBeforeIt() {
      var generation = RouteRequestGeneration()

      let first = generation.issue()
      let second = generation.issue()

      #expect(generation.isCurrent(first) == false)
      #expect(generation.isCurrent(second))
   }

   @Test func ticketsAreNeverHandedOutTwice() {
      var generation = RouteRequestGeneration()
      let tickets = (0..<50).map { _ in generation.issue() }

      #expect(Set(tickets).count == tickets.count)
      #expect(tickets == tickets.sorted())
   }

   // MARK: - Retiring

   @Test func retiringAllLeavesNoTicketCurrent() {
      var generation = RouteRequestGeneration()
      let ticket = generation.issue()

      generation.retireAll()

      #expect(generation.isCurrent(ticket) == false)
   }

   @Test func aTicketIssuedAfterRetiringIsCurrentAgain() {
      var generation = RouteRequestGeneration()

      _ = generation.issue()
      generation.retireAll()
      let fresh = generation.issue()

      #expect(generation.isCurrent(fresh))
   }

   // MARK: - Out-Of-Order Answers

   /// The case this exists for: three keystrokes in flight, answers landing in
   /// the wrong order. Only the newest may publish, whenever it arrives.
   @Test func onlyTheNewestRequestMayPublishHoweverTheAnswersLand() {
      var generation = RouteRequestGeneration()

      let ma = generation.issue()
      let mai = generation.issue()
      let main = generation.issue()

      var published: [String] = []

      for (ticket, results) in [(main, "main"), (ma, "ma"), (mai, "mai")]
      where generation.isCurrent(ticket) {
         published.append(results)
      }

      #expect(published == ["main"])
   }

   @Test func aTicketRetiredMidFlightCannotClobberACleanedUpList() {
      var generation = RouteRequestGeneration()
      let inFlight = generation.issue()

      // The rider clears the field while the request is still out.
      generation.retireAll()

      #expect(generation.isCurrent(inFlight) == false)
   }

   // MARK: - Value Semantics

   /// Copies must not share a counter, or one screen's cancellation would retire
   /// another's request.
   @Test func aCopyKeepsItsOwnCounter() {
      var original = RouteRequestGeneration()
      let ticket = original.issue()

      var copy = original
      _ = copy.issue()

      #expect(original.isCurrent(ticket))
      #expect(copy.isCurrent(ticket) == false)
   }
}
