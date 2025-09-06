#!/bin/bash

# Test version functionality
# Tests that the CLI reports the correct version from version.go

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_ROOT/bin/emoji-sad"

echo "=== Testing Version Functionality ==="

# Check if binary exists
if [[ ! -f "$BINARY" ]]; then
    echo "ERROR: Binary not found at $BINARY"
    echo "Please run 'make build' first"
    exit 1
fi

# Get expected version from version.go
EXPECTED_VERSION=$(grep 'Version = ' "$PROJECT_ROOT/internal/version/version.go" | sed 's/.*"\(.*\)".*/\1/')

if [[ -z "$EXPECTED_VERSION" ]]; then
    echo "ERROR: Could not extract version from internal/version/version.go"
    exit 1
fi

echo "Expected version: $EXPECTED_VERSION"

# Test --version flag
echo "Testing --version flag..."
VERSION_OUTPUT=$("$BINARY" --version 2>&1 || true)
echo "Version output: $VERSION_OUTPUT"

# Check if output contains expected version
if [[ "$VERSION_OUTPUT" == *"$EXPECTED_VERSION"* ]]; then
    echo "✓ --version flag returns correct version"
else
    echo "✗ --version flag failed"
    echo "Expected version '$EXPECTED_VERSION' in output '$VERSION_OUTPUT'"
    exit 1
fi

# Test -v flag (short version)
echo "Testing -v flag..."
VERSION_OUTPUT_SHORT=$("$BINARY" -v 2>&1 || true)
echo "Short version output: $VERSION_OUTPUT_SHORT"

# Check if short version output contains expected version
if [[ "$VERSION_OUTPUT_SHORT" == *"$EXPECTED_VERSION"* ]]; then
    echo "✓ -v flag returns correct version"
else
    echo "✗ -v flag failed"
    echo "Expected version '$EXPECTED_VERSION' in output '$VERSION_OUTPUT_SHORT'"
    exit 1
fi

# Test that version output has proper format
echo "Testing version output format..."
if [[ "$VERSION_OUTPUT" =~ emoji-sad\ version\ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "✓ Version output has correct format"
else
    echo "✗ Version output format is incorrect"
    echo "Expected format like 'emoji-sad version X.Y.Z', got: $VERSION_OUTPUT"
    exit 1
fi

echo ""
echo "✅ All version tests passed!"