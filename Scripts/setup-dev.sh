#!/bin/bash
# Scripts/setup-dev.sh
# Patches team ID and bundle identifiers for local development

set -euo pipefail

echo "=== MacMeetingCam Developer Setup ==="
echo ""

read -p "Enter your Apple Developer Team ID (e.g., ABCDE12345): " TEAM_ID

if [ -z "$TEAM_ID" ]; then
    echo "Error: Team ID is required"
    exit 1
fi

echo ""
echo "Patching project with Team ID: $TEAM_ID"

# Regenerate project with the team ID
if command -v xcodegen &> /dev/null; then
    TEAM_ID="$TEAM_ID" xcodegen generate
    echo "Project regenerated with your Team ID."
else
    echo "XcodeGen not found. Install with: brew install xcodegen"
    echo "Then re-run this script."
    exit 1
fi

echo ""
echo "Setup complete! Open MacMeetingCam.xcodeproj in Xcode."
echo ""
echo "Schemes available:"
echo "  - MacMeetingCam (Full): Builds host app + Camera Extension (requires signing)"
echo "  - MacMeetingCam (No Extension): Builds host app only (no signing needed)"
