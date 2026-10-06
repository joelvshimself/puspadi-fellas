#!/bin/bash
# Xcode "Build shared module" phase: compiles Mobile/shared into Shared.framework
# for the platform/configuration Xcode is building. See CLAUDE.md.
set -euo pipefail

# Xcode doesn't inherit your shell, so find a JDK the way a terminal would.
if [ -z "${JAVA_HOME:-}" ]; then
  for candidate in /opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home \
                   /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
                   "/Applications/Android Studio.app/Contents/jbr/Contents/Home"; do
    if [ -x "$candidate/bin/java" ]; then export JAVA_HOME="$candidate"; break; fi
  done
  [ -z "${JAVA_HOME:-}" ] && export JAVA_HOME="$(/usr/libexec/java_home)"
fi

cd "$SRCROOT"
./gradlew :shared:embedAndSignAppleFrameworkForXcode --console=plain
