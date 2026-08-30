# CaliphBar Release Guide

## Local development build

```bash
swift test
./build-app.sh
```

Verify the Universal Binary and bundle signature:

```bash
lipo -info CaliphBar.app/Contents/MacOS/CaliphBar
codesign --verify --deep --strict CaliphBar.app
```

Expected architectures: `arm64` and `x86_64`.

## Install locally

```bash
./install.sh
pkill CaliphBar 2>/dev/null || true
open /Applications/CaliphBar.app
```

## Pre-merge gate

Before a release-worthy merge:

- core tests pass
- Universal Binary build passes
- code-signature verification passes
- provider semantics have not silently changed
- user-visible strings remain localized
- documentation reflects provider/data-source changes
- material UI work passes `design-qa.md` locally

## Public release considerations

The current local build uses ad-hoc signing. A polished public release should add:

1. stable Apple Developer ID signing
2. notarization
3. reproducible release packaging (DMG or ZIP)
4. versioned GitHub Releases
5. release notes describing provider/data-source changes
6. checksum publication

Keep signing/notarization credentials outside the repository and use GitHub Actions secrets only when a release workflow is intentionally introduced.

## Third-party data

A public release containing Codex Radar or another third-party intelligence feed must follow that source's current attribution and derivative-use terms. Public reachability of JSON is not by itself permission for unrestricted redistribution or commercial use.
