#!/usr/bin/env python3
"""Offline checks of the actual app Radar state model; no network or account data."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
source = (repo / 'Sources/CaliphBar/Services/CodexRadarStore.swift').read_text()
model = source[source.index('enum CodexRadarSignal:'):source.index('struct CodexLocalResetConfirmation:')]
main = r'''
import Foundation
@main struct Check {
    static func main() throws {
        func check(_ value: Bool) { precondition(value) }
        let now = Date(timeIntervalSince1970: 1791200000)
        func snapshot(_ status: String, age: Double = 0, monitor: String = "healthy", kind: String = "direct_reset") throws -> CodexRadarSnapshot {
            let json = """
            {"schemaVersion":1,"checkedAt":"2026-10-05T20:30:18+08:00","events":[{"id":"fixture","type":"\(kind)","status":"\(status == "confirmed" ? "confirmed" : "announced")","updatedAt":"2026-10-03T12:28:21+08:00","presentation":{"status":"\(status)"}}]}
            """
            let feed = try AIHotResetFeed.parse(Data(json.utf8))
            var result = CodexRadarSnapshot(windowOpen: true, status: status,
                recommendedAction: nil, message: nil, windowTitle: nil, windowScope: nil,
                openedAt: nil, predictionLevel: nil, probability24h: nil, probability48h: nil,
                summary: nil, closedAt: nil, sourceURL: nil,
                sourceUpdatedAt: now.addingTimeInterval(-age), fetchedAt: now, announcement: nil)
            result.event = feed.selectedEvent
            result.monitorStatus = monitor
            return result
        }
        check(try snapshot("announced").signal(now: now) == .watch)
        check(try snapshot("in_progress").signal(now: now) == .hot)
        check(try snapshot("confirmed").signal(now: now) == .quiet)
        check(try snapshot("likely_completed").signal(now: now) == .watch)
        check(try snapshot("expired_unconfirmed").signal(now: now) == .watch)
        check(try snapshot("in_progress", age: 7201).signal(now: now) == .stale)
        check(try snapshot("in_progress", monitor: "delayed").signal(now: now) == .stale)
        check(try snapshot("announced", kind: "reset_credit").signal(now: now) == .quiet)
        let original = try snapshot("announced")
        let roundTrip = try JSONDecoder().decode(CodexRadarSnapshot.self, from: JSONEncoder().encode(original))
        check(roundTrip.event == original.event)
        print("PASS 9 radar status/freshness/cache checks")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='caliph-radar-check-') as scratch:
    root = Path(scratch)
    (root / 'model.swift').write_text('import Foundation\n' + model)
    (root / 'main.swift').write_text(main)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library',
                    str(repo / 'Sources/CaliphBarCore/AIHotResetFeed.swift'),
                    str(root / 'model.swift'), str(root / 'main.swift'), '-o', str(root / 'check')], check=True, timeout=90)
    subprocess.run([str(root / 'check')], check=True, timeout=10)
