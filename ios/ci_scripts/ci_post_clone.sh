#!/bin/sh

# Xcode Cloud runs this script automatically right after cloning the repo,
# before Xcode resolves any package dependencies. The build image has no
# Flutter installed, and ios/Flutter/ephemeral/ doesn't exist yet — it's
# gitignored and only ever generated locally by `flutter pub get` /
# `flutter build`. That's exactly what made archive builds fail with
# "the package at .../FlutterGeneratedPluginSwiftPackage cannot be
# accessed", since Runner.xcodeproj references a local Swift Package
# inside that directory. This script installs Flutter and regenerates it
# before Xcode continues.
set -e

git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter precache --ios
flutter pub get

# Regenerates ios/Flutter/ephemeral/, including the local
# FlutterGeneratedPluginSwiftPackage that Runner.xcodeproj references.
flutter build ios --config-only -t lib/main.dart

# flutter_local_notifications doesn't support Swift Package Manager yet, so
# it's still pulled in via CocoaPods (see ios/Podfile) — Pods/ is gitignored
# the same way, so it needs regenerating here too.
command -v pod >/dev/null 2>&1 || (HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods)
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install
