#!/bin/bash
# Scripts/ci-test.sh
# Full CI test runner: build, test, coverage check

set -euo pipefail

SCHEME="${1:-MacMeetingCam (No Extension)}"
RESULT_BUNDLE=".build/results.xcresult"
COVERAGE_THRESHOLD=90

echo "=== MacMeetingCam CI Test Runner ==="
echo "Scheme: $SCHEME"
echo ""

# Clean previous results
rm -rf "$RESULT_BUNDLE"

# Step 1: Build all targets
echo "--- Step 1: Building ---"
xcodebuild build-for-testing \
    -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -resultBundlePath "$RESULT_BUNDLE" \
    2>&1 | tail -3

# Step 2: Run unit tests with coverage
echo ""
echo "--- Step 2: Unit Tests ---"
xcodebuild test-without-building \
    -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -only-testing:MacMeetingCamTests \
    -resultBundlePath "$RESULT_BUNDLE" \
    -enableCodeCoverage YES \
    2>&1 | tail -5

# Step 3: Run integration tests
echo ""
echo "--- Step 3: Integration Tests ---"
xcodebuild test-without-building \
    -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -only-testing:MacMeetingCamIntegrationTests \
    -resultBundlePath "$RESULT_BUNDLE" \
    2>&1 | tail -5

# Step 4: Run E2E tests (includes visual regression)
echo ""
echo "--- Step 4: E2E Tests ---"
xcodebuild test-without-building \
    -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -only-testing:MacMeetingCamE2ETests \
    -resultBundlePath "$RESULT_BUNDLE" \
    2>&1 | tail -5

# Step 5: Run performance benchmarks
echo ""
echo "--- Step 5: Performance Tests ---"
xcodebuild test-without-building \
    -scheme "$SCHEME" \
    -destination "platform=macOS" \
    -only-testing:MacMeetingCamPerformanceTests \
    -resultBundlePath "$RESULT_BUNDLE" \
    2>&1 | tail -5

# Step 6: Check coverage
echo ""
echo "--- Step 6: Coverage Check ---"
./Scripts/check-coverage.sh "$RESULT_BUNDLE" "$COVERAGE_THRESHOLD"

echo ""
echo "=== CI Complete ==="
