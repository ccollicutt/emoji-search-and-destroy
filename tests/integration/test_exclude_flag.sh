#!/bin/bash

# Integration test for --exclude flag functionality

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_DIR/bin/emoji-sad"

echo "=== Testing --exclude Flag Functionality ==="

# Test configuration
TEST_DIR="/tmp/emoji_test_exclude_$$"

# Setup test data
echo "Setting up test data..."
mkdir -p "$TEST_DIR/node_modules"
mkdir -p "$TEST_DIR/vendor"
mkdir -p "$TEST_DIR/src"
mkdir -p "$TEST_DIR/build"
mkdir -p "$TEST_DIR/config"
mkdir -p "$TEST_DIR/tests"

# Create files with emojis in various directories
echo "Root file with emoji 😊" > "$TEST_DIR/root.txt"
echo "Node modules emoji 🎉" > "$TEST_DIR/node_modules/package.json"
echo "Vendor file emoji 🔥" > "$TEST_DIR/vendor/lib.go"
echo "Source code emoji 🚀" > "$TEST_DIR/src/main.go"
echo "Build output emoji 🏗️" > "$TEST_DIR/build/output.txt"
echo "Config file emoji 💻" > "$TEST_DIR/config.json"
echo "Test file emoji ⚡" > "$TEST_DIR/tests/app.test.js"
echo "Another test emoji 🌟" > "$TEST_DIR/tests/unit.spec.js"
echo "Important file emoji 🎨" > "$TEST_DIR/important.md"

echo "Test directory structure created"

# Test 1: Exclude single directory
echo "Test 1: Testing single directory exclusion (node_modules)..."
output=$("$BINARY" --list-only --exclude node_modules "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: --exclude command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

echo "Output with node_modules excluded:"
echo "$output"
echo

# Should NOT contain node_modules files
if echo "$output" | grep -q "node_modules"; then
    echo "FAIL: Should not list files in excluded node_modules directory"
    exit 1
fi

# Should contain other files
if ! echo "$output" | grep -q "root.txt"; then
    echo "FAIL: Should list root.txt"
    exit 1
fi

echo "✓ Single directory exclusion works"

# Test 2: Exclude multiple directories
echo "Test 2: Testing multiple directory exclusions..."
output=$("$BINARY" --list-only --exclude node_modules --exclude vendor --exclude build "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Multiple --exclude command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

echo "Output with multiple directories excluded:"
echo "$output"
echo

# Should NOT contain excluded directories
if echo "$output" | grep -q "node_modules\|vendor\|build"; then
    echo "FAIL: Should not list files in excluded directories"
    exit 1
fi

# Should still contain non-excluded files
if ! echo "$output" | grep -q "root.txt"; then
    echo "FAIL: Should still list root.txt"
    exit 1
fi

if ! echo "$output" | grep -q "main.go"; then
    echo "FAIL: Should still list src/main.go"
    exit 1
fi

echo "✓ Multiple directory exclusions work"

# Test 3: Exclude specific file
echo "Test 3: Testing specific file exclusion..."
output=$("$BINARY" --list-only --exclude config.json "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: File exclusion command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

# Should NOT contain config.json
if echo "$output" | grep -q "config.json"; then
    echo "FAIL: Should not list excluded config.json"
    exit 1
fi

# Should contain other files
if ! echo "$output" | grep -q "root.txt"; then
    echo "FAIL: Should still list other files"
    exit 1
fi

echo "✓ Specific file exclusion works"

# Test 4: Exclude using glob patterns
echo "Test 4: Testing glob pattern exclusion..."
output=$("$BINARY" --list-only --exclude "*.spec.js" "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Glob pattern exclusion command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

echo "Output with *.spec.js excluded:"
echo "$output"
echo

# Should NOT contain .spec.js files
if echo "$output" | grep -q "unit.spec.js"; then
    echo "FAIL: Should not list files matching *.spec.js pattern"
    exit 1
fi

# Should still contain .test.js files
if ! echo "$output" | grep -q "app.test.js"; then
    echo "FAIL: Should still list app.test.js (doesn't match *.spec.js)"
    exit 1
fi

echo "✓ Glob pattern exclusion works"

# Test 5: Test actual file modification with exclusions
echo "Test 5: Testing actual file modification with exclusions..."

# Process files excluding node_modules and vendor
output=$("$BINARY" --no-dry-run --exclude node_modules --exclude vendor "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: File modification with exclusions failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

# Check that excluded files still have emojis
if ! grep -q "🎉" "$TEST_DIR/node_modules/package.json"; then
    echo "FAIL: node_modules/package.json should not have been modified"
    exit 1
fi

if ! grep -q "🔥" "$TEST_DIR/vendor/lib.go"; then
    echo "FAIL: vendor/lib.go should not have been modified"
    exit 1
fi

# Check that non-excluded files had emojis removed
if grep -q "😊" "$TEST_DIR/root.txt"; then
    echo "FAIL: root.txt should have had emojis removed"
    exit 1
fi

if grep -q "🚀" "$TEST_DIR/src/main.go"; then
    echo "FAIL: src/main.go should have had emojis removed"
    exit 1
fi

echo "✓ File modification respects exclusions"

# Test 6: Complex exclusion patterns
echo "Test 6: Testing complex exclusion patterns..."

# Restore ALL files with emojis since test 5 modified them
echo "Root file with emoji 😊" > "$TEST_DIR/root.txt"
echo "Node modules emoji 🎉" > "$TEST_DIR/node_modules/package.json"
echo "Vendor file emoji 🔥" > "$TEST_DIR/vendor/lib.go"
echo "Source code emoji 🚀" > "$TEST_DIR/src/main.go"
echo "Build output emoji 🏗️" > "$TEST_DIR/build/output.txt"
echo "Config file emoji 💻" > "$TEST_DIR/config.json"
echo "Test file emoji ⚡" > "$TEST_DIR/tests/app.test.js"
echo "Another test emoji 🌟" > "$TEST_DIR/tests/unit.spec.js"
echo "Important file emoji 🎨" > "$TEST_DIR/important.md"

# Use multiple different types of exclusions
output=$("$BINARY" --list-only --exclude node_modules --exclude "*.spec.js" --exclude config.json --exclude vendor "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Complex exclusion patterns failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

# Count remaining files - should exclude 4 items (node_modules/*, vendor/*, config.json, *.spec.js)
# Filter out empty lines before counting
line_count=$(echo "$output" | grep -v '^$' | wc -l)
expected_count=5  # root.txt, src/main.go, build/output.txt, tests/app.test.js, important.md

if [ "$line_count" -ne "$expected_count" ]; then
    echo "FAIL: Expected $expected_count files after exclusions, got $line_count"
    echo "Files listed:"
    echo "$output"
    exit 1
fi

echo "✓ Complex exclusion patterns work correctly"

# Test 7: Absolute path exclusion
echo "Test 7: Testing absolute path exclusion..."
output=$("$BINARY" --list-only --exclude "$TEST_DIR/build" "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Absolute path exclusion failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

# Should NOT contain build directory files
if echo "$output" | grep -q "build/output.txt"; then
    echo "FAIL: Should not list files in absolutely excluded build directory"
    exit 1
fi

echo "✓ Absolute path exclusion works"

# Clean up
rm -rf "$TEST_DIR" 2>/dev/null || true

echo "PASS: All --exclude flag tests passed"
echo "✓ Single directory exclusion"
echo "✓ Multiple directory exclusions"
echo "✓ Specific file exclusion"
echo "✓ Glob pattern exclusion"
echo "✓ File modification respects exclusions"
echo "✓ Complex exclusion patterns"
echo "✓ Absolute path exclusion"
echo