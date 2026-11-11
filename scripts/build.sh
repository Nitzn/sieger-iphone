#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build out
python3 scripts/validate_sources.py
swift scripts/make_icon.swift
swiftc -parse-as-library SIEGER/Models.swift SIEGER/SnapshotIO.swift SIEGER/LiveResearch.swift Checks/Checks.swift -o .build/model-checks
.build/model-checks
xcodebuild -project SIEGER.xcodeproj -scheme SIEGER -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath .build/device \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build
python3 scripts/package_ipa.py .build/device/Build/Products/Release-iphoneos/SIEGER.app out/SIEGER-unsigned.ipa
shasum -a 256 out/SIEGER-unsigned.ipa > out/SIEGER-unsigned.ipa.sha256
printf '%s\n' 'Unsig­niertes Gerätepaket erstellt. Vor dem Start mit SideStore/AltStore/iloader persönlich signieren.'
