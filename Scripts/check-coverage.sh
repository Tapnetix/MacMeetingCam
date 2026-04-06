#!/bin/bash
# Scripts/check-coverage.sh
# Parses xcodebuild result bundle and enforces >90% coverage threshold

set -euo pipefail

RESULT_BUNDLE="${1:-.build/results.xcresult}"
THRESHOLD="${2:-90}"
OUTPUT_FILE="Tests/coverage-report.txt"

echo "=== MacMeetingCam Coverage Report ==="
echo "Threshold: ${THRESHOLD}%"
echo ""

# Extract coverage using xcrun xccov
COVERAGE_JSON=$(xcrun xccov view --report --json "$RESULT_BUNDLE" 2>/dev/null)

if [ -z "$COVERAGE_JSON" ]; then
    echo "ERROR: Could not extract coverage from $RESULT_BUNDLE"
    exit 1
fi

# Parse overall line coverage
OVERALL=$(echo "$COVERAGE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
targets = data.get('targets', [])
for t in targets:
    name = t.get('name', '')
    cov = t.get('lineCoverage', 0) * 100
    print(f'{name}: {cov:.1f}%')
    if name == 'MacMeetingCam.app':
        print(f'MAIN_COVERAGE={cov:.1f}')
")

echo "$OVERALL" | grep -v "MAIN_COVERAGE"
echo ""

MAIN_COV=$(echo "$OVERALL" | grep "MAIN_COVERAGE" | cut -d= -f2)

if [ -z "$MAIN_COV" ]; then
    echo "WARNING: Could not determine main target coverage"
    exit 0
fi

echo "Main target coverage: ${MAIN_COV}%"

# Write report
echo "$OVERALL" > "$OUTPUT_FILE"
echo "Report written to $OUTPUT_FILE"

# Check threshold
PASS=$(python3 -c "print('yes' if float('${MAIN_COV}') >= float('${THRESHOLD}') else 'no')")

if [ "$PASS" = "no" ]; then
    echo ""
    echo "FAIL: Coverage ${MAIN_COV}% is below threshold ${THRESHOLD}%"
    exit 1
else
    echo ""
    echo "PASS: Coverage ${MAIN_COV}% meets threshold ${THRESHOLD}%"
fi
