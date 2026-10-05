#!/usr/bin/env python3
"""Offline quota transport regression checks; no real CLI, credentials or network."""
import json
import os
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import time

repo = Path(__file__).resolve().parents[1]
swift = r'''
import Foundation
@main struct Check {
    static func main() async throws {
        let mode = CommandLine.arguments[1]
        let started = ProcessInfo.processInfo.systemUptime
        if mode == "cancel" {
            let task = Task { try await CodexAppServerProbe().fetchRateLimits() }
            try await Task.sleep(nanoseconds: 250_000_000)
            task.cancel()
            do { _ = try await task.value; fatalError("cancel unexpectedly succeeded") } catch {}
            assert(ProcessInfo.processInfo.systemUptime - started < 2)
        } else {
            let session = try CodexRPCSession(timeout: mode == "timeout" ? 0.4 : 4, flushAfter: 0.1)
            defer { session.shutdown() }
            if mode == "exit" {
                try await Task.sleep(nanoseconds: 250_000_000)
                CodexQuotaProbeLifecycle.shutdown()
                do { _ = try CodexRPCSession(); fatalError("spawn allowed during exit") } catch {}
            } else if ["success", "partial", "stderr", "eof", "stdin_eof"].contains(mode) {
                _ = try session.fetchRateLimitsOneShot()
            } else {
                do {
                    _ = try session.fetchRateLimitsOneShot()
                    fatalError("expected failure: \(mode)")
                } catch let error as CodexAppServerError {
                    if mode == "timeout" {
                        guard case .timeout = error else { fatalError("wrong timeout error") }
                    }
                }
            }
        }
        print("PASS \(mode) \(String(format: "%.2f", ProcessInfo.processInfo.systemUptime - started))s")
    }
}
'''
fake = r'''
import json, os, signal, sys, time
assert sys.argv[1:] == ["--disable", "plugins", "-s", "read-only", "-a", "never", "app-server"]
mode = os.environ["PROBE_CASE"]
child = os.fork()
if child == 0:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    while True: time.sleep(1)
with open(os.environ["PROBE_PIDS"], "w") as f:
    json.dump([os.getpid(), child], f)
if mode in ("timeout", "cancel", "exit"):
    while True: time.sleep(1)
for _ in range(3): json.loads(sys.stdin.readline())
if mode == "stdin_eof": sys.stdin.read()
if mode == "closed":
    os.kill(child, signal.SIGKILL)
    sys.exit(0)
if mode == "overflow":
    sys.stdout.write("x" * 1100000); sys.stdout.flush()
    time.sleep(10)
if mode == "stderr":
    sys.stderr.buffer.write(b"x" * 262144); sys.stderr.flush()
if mode == "rpc": response = {"id": 2, "error": {"message": "fixture"}}
elif mode == "invalid": response = {"id": 2, "result": {}}
else: response = {"id": 2, "result": {"rateLimits": {"primary": {"usedPercent": 12}}}}
data = json.dumps(response) + ("" if mode == "eof" else "\n")
sys.stdout.write('{"method":"notification"}\n'); sys.stdout.flush()
if mode == "partial":
    for char in data: sys.stdout.write(char); sys.stdout.flush(); time.sleep(0.001)
else:
    sys.stdout.write(data); sys.stdout.flush()
if mode == "eof":
    os.kill(child, signal.SIGKILL)
    sys.exit(0)
time.sleep(10)
'''

def alive(pid):
    status = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
    return bool(status) and not status.startswith("Z")

with tempfile.TemporaryDirectory(prefix="caliph-probe-check-") as scratch:
    root = Path(scratch)
    main, fixture, binary, pids = (root / n for n in ("check.swift", "fake-codex", "check", "pids.json"))
    main.write_text(swift)
    fixture.write_text("#!" + sys.executable + "\n" + fake)
    fixture.chmod(0o700)
    core = sorted(str(p) for p in (repo / "Sources/CaliphBarCore").rglob("*.swift"))
    subprocess.run(["xcrun", "swiftc", "-Onone", "-swift-version", "5", "-parse-as-library",
                    *core, str(main), "-o", str(binary)], check=True, timeout=120)
    for mode in ("success", "partial", "stderr", "eof", "stdin_eof", "closed", "rpc", "invalid", "overflow", "timeout", "cancel", "exit"):
        pids.unlink(missing_ok=True)
        env = dict(os.environ, CODEX_CLI_PATH=str(fixture), PROBE_CASE=mode, PROBE_PIDS=str(pids))
        try:
            result = subprocess.run([str(binary), mode], env=env, capture_output=True, text=True, timeout=8)
            time.sleep(0.1)
            launched = json.loads(pids.read_text()) if pids.exists() else []
            survivors = [pid for pid in launched if alive(pid)]
            assert result.returncode == 0 and not survivors, (mode, result.stdout, result.stderr, survivors)
            print(result.stdout.strip(), flush=True)
        finally:
            # A failing regression must not leave its own fake CLI/helpers behind.
            # Match both the recorded group and this unique temporary fixture path.
            if pids.exists():
                group = json.loads(pids.read_text())[0]
                for line in subprocess.check_output(["ps", "-axo", "pgid=,args="], text=True).splitlines():
                    fields = line.split(None, 1)
                    if len(fields) == 2 and fields[0] == str(group) and str(fixture) in fields[1]:
                        try: os.killpg(group, signal.SIGKILL)
                        except ProcessLookupError: pass
                        break
    print("PASS all 12 offline quota transport checks")
