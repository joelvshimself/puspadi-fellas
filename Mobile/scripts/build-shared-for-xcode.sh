#!/bin/bash
# Xcode "Build shared module" phase: compiles Mobile/shared into Shared.framework
# for the platform/configuration Xcode is building. See CLAUDE.md.
set -euo pipefail

# Xcode may inherit a broken JAVA_HOME from ~/.zshrc; only keep it when java exists.
if [ -n "${JAVA_HOME:-}" ] && [ ! -x "${JAVA_HOME}/bin/java" ]; then
  unset JAVA_HOME
fi
if [ -z "${JAVA_HOME:-}" ]; then
  for candidate in "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
                   /opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home \
                   /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home; do
    if [ -x "$candidate/bin/java" ]; then export JAVA_HOME="$candidate"; break; fi
  done
fi
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME}/bin/java" ]; then
  if [ -x /usr/libexec/java_home ]; then
    export JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null || true)"
  fi
fi
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME}/bin/java" ]; then
  echo "No JDK found for Gradle (shared module). Install Android Studio or: brew install openjdk@25" >&2
  exit 1
fi

cd "$SRCROOT"
./gradlew :shared:embedAndSignAppleFrameworkForXcode --console=plain

# Gradle may emit …/Debug/iphoneos27.0/ while Xcode's FRAMEWORK_SEARCH_PATHS uses $(SDK_NAME)
# (e.g. iphoneos). Symlink so Swift can resolve `import Shared`.
if [ -n "${CONFIGURATION:-}" ] && [ -n "${SDK_NAME:-}" ]; then
  base="${SRCROOT}/shared/build/xcode-frameworks/${CONFIGURATION}"
  expected="${base}/${SDK_NAME}/Shared.framework"
  if [ ! -d "$expected" ]; then
    found="$(find "$base" -maxdepth 2 -path '*/Shared.framework' -type d 2>/dev/null | head -1)"
    if [ -n "$found" ]; then
      mkdir -p "${base}/${SDK_NAME}"
      ln -snf "$(cd "$(dirname "$found")" && pwd)/$(basename "$found")" "$expected"
      echo "Linked Shared.framework for SDK_NAME=${SDK_NAME} → $(basename "$(dirname "$found")")"
    fi
  fi
fi
