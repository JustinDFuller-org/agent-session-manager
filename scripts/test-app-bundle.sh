#!/usr/bin/env bash
set -euo pipefail

app_bundle="${1:?app bundle path is required}"
executable="$app_bundle/Contents/MacOS/$(basename "$app_bundle" .app)"
bridge_executable="$app_bundle/Contents/Helpers/AgentSessionManagerMCPBridge"
framework_binary="$app_bundle/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle"

[[ -d "$app_bundle" ]] || {
    echo "app bundle not found: $app_bundle" >&2
    exit 1
}
[[ -x "$executable" ]] || {
    echo "app executable not found: $executable" >&2
    exit 1
}
[[ -x "$bridge_executable" ]] || {
    echo "Agent Control MCP bridge not found: $bridge_executable" >&2
    exit 1
}
[[ -f "$framework_binary" ]] || {
    echo "Sparkle framework is not embedded: $framework_binary" >&2
    exit 1
}

otool -L "$executable" | grep -Fq '@rpath/Sparkle.framework/Versions/B/Sparkle' || {
    echo "app executable does not link Sparkle through @rpath" >&2
    exit 1
}
otool -l "$executable" | grep -Fq 'path @executable_path/../Frameworks' || {
    echo "app executable does not search Contents/Frameworks" >&2
    exit 1
}
codesign --verify --deep --strict "$app_bundle"
codesign --verify --strict "$bridge_executable"

echo "Standalone app bundle passed: $app_bundle"
