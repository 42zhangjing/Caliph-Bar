import Foundation
import Testing
@testable import CaliphBarCore

@Suite struct AIHotResetFeedTests {
    private func feed(_ events: String, version: Int = 1, checkedAt: String = "\"2026-10-05T20:30:18.379+08:00\"") throws -> AIHotResetFeed {
        try AIHotResetFeed.parse(Data("""
        {"schemaVersion":\(version),"checkedAt":\(checkedAt),"events":[\(events)],"unknown":true}
        """.utf8))
    }
    private func event(_ id: String, type: String = "direct_reset", status: String = "confirmed", extra: String = "") -> String {
        """
        {"id":"\(id)","type":"\(type)","status":"\(status)","updatedAt":"2026-10-03T12:28:21+08:00"\(extra)}
        """
    }

    @Test func pendingResetWinsOverHistoricalConfirmationAndCredits() throws {
        let result = try feed([event("old"), event("card", type: "reset_credit", status: "announced"), event("pending", status: "announced")].joined(separator: ","))
        #expect(result.selectedEvent?.id == "pending")
        #expect(result.selectedEvent?.isConfirmed == false)
    }
    @Test func creditsNeverBecomeDirectReset() throws {
        let result = try feed(event("card", type: "reset_credit"))
        #expect(result.selectedEvent?.isDirectReset == false)
        #expect(result.selectedEvent?.headline(isChinese: true) == "重置卡发放已确认")
    }
    @Test func estimateDoesNotConfirmOrRemainTargetAfterConfirmation() throws {
        let extra = ",\"estimate\":{\"through\":\"2026-10-06T10:00:00+08:00\",\"basis\":\"history\"},\"presentation\":{\"status\":\"likely_completed\"}"
        let result = try feed(event("pending", status: "announced", extra: extra))
        #expect(result.selectedEvent?.isConfirmed == false)
        #expect(result.selectedEvent?.headline(isChinese: true).contains("未确认") == true)
        #expect(result.selectedEvent?.target != nil)
        #expect(try feed(event("done", extra: extra)).selectedEvent?.target == nil)
    }
    @Test func watermarkIsVerificationTimeAndMissingTimeStaysUnknown() throws {
        #expect(try feed("").verifiedAt != nil)
        #expect(try feed("", checkedAt: "null").verifiedAt == nil)
        #expect(try feed("").selectedEvent == nil)
    }
    @Test func replaceSnapshotAppliesWithdrawalsAndUnknownKindsAreIgnored() throws {
        #expect(try feed(event("old")).selectedEvent != nil)
        #expect(try feed("").selectedEvent == nil)
        #expect(try feed(event("future", type: "new_kind")).selectedEvent == nil)
    }
    @Test func unsupportedSchemaAndBrokenPayloadFail() {
        #expect(throws: (any Error).self) { try feed("", version: 2) }
        #expect(throws: (any Error).self) { try AIHotResetFeed.parse(Data("{}".utf8)) }
    }
}
