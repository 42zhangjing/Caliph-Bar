import Foundation
import Testing
@testable import CaliphBarCore

@Suite struct AntigravityQuotaSummaryTests {
    @Test func parsesGroupedQuotaSummaryAndUsesMostConstrainedCadence() throws {
        let json = #"""
        {
          "response": {
            "groups": [
              {
                "displayName": "Gemini Models",
                "buckets": [
                  {
                    "bucketId": "five-hour",
                    "displayName": "5-hour limit",
                    "remaining": { "remainingFraction": 0.85 },
                    "resetTime": "2026-08-31T03:30:00Z"
                  },
                  {
                    "bucketId": "weekly",
                    "displayName": "Weekly limit",
                    "remainingFraction": 0.40
                  }
                ]
              },
              {
                "displayName": "Claude and GPT models",
                "buckets": [
                  {
                    "bucketId": "session",
                    "displayName": "5-hour limit",
                    "remainingFraction": 0.65
                  },
                  {
                    "bucketId": "weekly-limit",
                    "displayName": "Weekly limit",
                    "remaining": { "case": "remainingFraction", "value": 0.90 }
                  }
                ]
              }
            ]
          }
        }
        """#

        let summary = try AntigravityQuotaSummaryParser.parse(Data(json.utf8))
        #expect(summary.groups.count == 2)

        let snapshot = try AntigravityProvider.makeSnapshot(from: summary)
        #expect(snapshot.provider == .gemini)
        #expect(snapshot.source == .live)
        #expect(snapshot.windows.count == 2)

        let session = snapshot.windows.first { $0.id == "session" }
        let weekly = snapshot.windows.first { $0.id == "weekly" }
        #expect(abs((session?.usedFraction ?? -1) - 0.35) < 0.0001)
        #expect(abs((weekly?.usedFraction ?? -1) - 0.60) < 0.0001)
        #expect(session?.resetsAt == nil)
    }

    @Test func supportsRootGroupsAndEpochReset() throws {
        let json = #"""
        {
          "groups": [
            {
              "displayName": "Gemini Models",
              "buckets": [
                {
                  "bucketId": "5h",
                  "displayName": "5h",
                  "remainingFraction": 0.25,
                  "resetTime": 1788134400
                }
              ]
            }
          ]
        }
        """#

        let summary = try AntigravityQuotaSummaryParser.parse(Data(json.utf8))
        let snapshot = try AntigravityProvider.makeSnapshot(from: summary)
        #expect(snapshot.windows.count == 1)
        #expect(snapshot.windows[0].id == "session")
        #expect(abs(snapshot.windows[0].usedFraction - 0.75) < 0.0001)
        #expect(snapshot.windows[0].resetsAt != nil)
    }

    @Test func ignoresDisabledAndUnknownUsageBuckets() throws {
        let json = #"""
        {
          "summary": {
            "groups": [
              {
                "displayName": "Gemini Models",
                "buckets": [
                  { "bucketId": "weekly", "displayName": "Weekly", "disabled": true, "remainingFraction": 0.10 },
                  { "bucketId": "five-hour", "displayName": "5-hour", "remaining": {} }
                ]
              }
            ]
          }
        }
        """#

        let summary = try AntigravityQuotaSummaryParser.parse(Data(json.utf8))
        #expect(throws: AntigravityProbeError.self) {
            _ = try AntigravityProvider.makeSnapshot(from: summary)
        }
    }
}
