#!/bin/bash

# Integration test for allow file functionality

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_DIR/bin/emoji-sad"

echo "=== Testing Allow File Functionality ==="

# Test configuration
TEST_DIR="/tmp/emoji_test_allow_$$"

# Show test dir on exit for debugging
trap 'echo "DEBUG: TEST_DIR was $TEST_DIR (not cleaned for debugging)"' EXIT

# Setup test data
echo "Setting up test data..."
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# Create files with various emojis including ones we'll allow
echo "Hello 😊 World 🚀 Test ✅ Done 🎉" > "$TEST_DIR/test1.txt"
echo "Project 🚀 Success ✅ Party 🎉 Happy 😊" > "$TEST_DIR/test2.txt"
echo "Check ✅ Launch 🚀 Smile 😊 Celebrate 🎉" > "$TEST_DIR/test3.txt"

# Test 1: Create allow file with some emojis
echo "Test 1: Testing with explicit allow file..."

# Create allow file just like other tests do - simple echo
echo "# This is a comment, should be ignored" > "$TEST_DIR/allow-list.txt"
echo "✅" >> "$TEST_DIR/allow-list.txt"
echo "🚀" >> "$TEST_DIR/allow-list.txt"
echo "" >> "$TEST_DIR/allow-list.txt"
echo "# Another comment" >> "$TEST_DIR/allow-list.txt"

# Run with allow file
output=$("$BINARY" --no-dry-run --allow-file "$TEST_DIR/allow-list.txt" "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Command with allow file failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

# Check that allowed emojis are preserved
content1=$(cat "$TEST_DIR/test1.txt")
if ! echo "$content1" | grep -q "✅"; then
    echo "FAIL: Allowed emoji ✅ was removed from test1.txt"
    echo "Content: $content1"
    exit 1
fi

if ! echo "$content1" | grep -q "🚀"; then
    echo "FAIL: Allowed emoji 🚀 was removed from test1.txt"
    echo "Content: $content1"
    exit 1
fi

# Check that non-allowed emojis are removed
if echo "$content1" | grep -q "😊"; then
    echo "FAIL: Non-allowed emoji 😊 was not removed from test1.txt"
    echo "Content: $content1"
    exit 1
fi

if echo "$content1" | grep -q "🎉"; then
    echo "FAIL: Non-allowed emoji 🎉 was not removed from test1.txt"
    echo "Content: $content1"
    exit 1
fi

echo "✓ Allow file works correctly with explicit path"

# Test 2: Test default .emoji-sad-allow file
echo "Test 2: Testing with default .emoji-sad-allow file..."

# Reset test files
echo "Hello 😊 World 🚀 Test ✅ Done 🎉" > "$TEST_DIR/test1.txt"
echo "Project 🚀 Success ✅ Party 🎉 Happy 😊" > "$TEST_DIR/test2.txt"

# Create default allow file in test directory
cd "$TEST_DIR"
echo "# Default allow list" > .emoji-sad-allow
echo "✅" >> .emoji-sad-allow

# Run without specifying allow file (should use default)
output=$("$BINARY" --no-dry-run . 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Command with default allow file failed with exit code $exit_code"
    echo "Output: $output"
    cd "$PROJECT_DIR"
    exit 1
fi

# Check that allowed emoji is preserved
content1=$(cat test1.txt)
if ! echo "$content1" | grep -q "✅"; then
    echo "FAIL: Allowed emoji ✅ from default file was removed"
    echo "Content: $content1"
    cd "$PROJECT_DIR"
    exit 1
fi

# Check that non-allowed emojis are removed
if echo "$content1" | grep -q "🚀"; then
    echo "FAIL: Non-allowed emoji 🚀 was not removed with default allow file"
    echo "Content: $content1"
    cd "$PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"

echo "✓ Default .emoji-sad-allow file works correctly"

# Test 3: Test with empty allow file (all emojis should be removed)
echo "Test 3: Testing with empty allow file..."

# Reset test files
echo "Hello 😊 World 🚀 Test ✅ Done 🎉" > "$TEST_DIR/test1.txt"

# Create empty allow file
touch "$TEST_DIR/empty-allow.txt"

output=$("$BINARY" --no-dry-run --allow-file "$TEST_DIR/empty-allow.txt" "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Command with empty allow file failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

# Check that all emojis are removed
content1=$(cat "$TEST_DIR/test1.txt")
if echo "$content1" | grep -qE '[😊🚀✅🎉]'; then
    echo "FAIL: Emojis were not removed with empty allow file"
    echo "Content: $content1"
    exit 1
fi

echo "✓ Empty allow file removes all emojis"

# Test 4: Test with stdin content processing and allow file
echo "Test 4: Testing stdin content with allow file..."

# Create temporary allow file for stdin test
echo "✅" > "$TEST_DIR/stdin-allow.txt"
echo "🚀" >> "$TEST_DIR/stdin-allow.txt"

result=$(echo "Hello 😊 World 🚀 Test ✅" | "$BINARY" --quiet --no-dry-run --allow-file "$TEST_DIR/stdin-allow.txt" -)

# Check that allowed emojis are preserved
if ! echo "$result" | grep -q "✅"; then
    echo "FAIL: Allowed emoji ✅ was removed from stdin"
    echo "Result: $result"
    exit 1
fi

if ! echo "$result" | grep -q "🚀"; then
    echo "FAIL: Allowed emoji 🚀 was removed from stdin"
    echo "Result: $result"
    exit 1
fi

# Check that non-allowed emoji is removed
if echo "$result" | grep -q "😊"; then
    echo "FAIL: Non-allowed emoji 😊 was not removed from stdin"
    echo "Result: $result"
    exit 1
fi

echo "✓ Stdin content processing respects allow file"

# Test 5: Test list-only mode with allow file
echo "Test 5: Testing list-only mode with allow file..."

# Reset test files
echo "Hello 😊 World 🚀 Test ✅ Done 🎉" > "$TEST_DIR/test1.txt"
echo "No emojis here" > "$TEST_DIR/test2.txt"
echo "Only allowed ✅ 🚀" > "$TEST_DIR/test3.txt"

output=$("$BINARY" --list-only --allow-file "$TEST_DIR/stdin-allow.txt" "$TEST_DIR" 2>&1)

# Should list test1.txt (has non-allowed emojis)
if ! echo "$output" | grep -q "test1.txt"; then
    echo "FAIL: test1.txt should be listed (has non-allowed emojis)"
    echo "Output: $output"
    exit 1
fi

# Should not list test3.txt (only has allowed emojis)
if echo "$output" | grep -q "test3.txt"; then
    echo "FAIL: test3.txt should not be listed (only has allowed emojis)"
    echo "Output: $output"
    exit 1
fi

echo "✓ List-only mode respects allow file"

# Test 6: Test JSON output with allow file
echo "Test 6: Testing JSON output with allow file..."

# Reset test files
echo "Hello 😊 World 🚀 Test ✅ Done 🎉" > "$TEST_DIR/test1.txt"

json_output=$("$BINARY" --output json --allow-file "$TEST_DIR/stdin-allow.txt" "$TEST_DIR" 2>&1)

# Check that JSON only reports non-allowed emojis
if ! echo "$json_output" | jq -e '.files[0].emojis_found | contains(["😊"])' >/dev/null 2>&1; then
    echo "FAIL: JSON should report non-allowed emoji 😊"
    echo "JSON: $json_output"
    exit 1
fi

if ! echo "$json_output" | jq -e '.files[0].emojis_found | contains(["🎉"])' >/dev/null 2>&1; then
    echo "FAIL: JSON should report non-allowed emoji 🎉"
    echo "JSON: $json_output"
    exit 1
fi

# Allowed emojis should not be in the report
if echo "$json_output" | jq -e '.files[0].emojis_found | contains(["✅"])' >/dev/null 2>&1; then
    echo "FAIL: JSON should not report allowed emoji ✅"
    echo "JSON: $json_output"
    exit 1
fi

if echo "$json_output" | jq -e '.files[0].emojis_found | contains(["🚀"])' >/dev/null 2>&1; then
    echo "FAIL: JSON should not report allowed emoji 🚀"
    echo "JSON: $json_output"
    exit 1
fi

echo "✓ JSON output respects allow file"

# Clean up
echo "TEST_DIR was: $TEST_DIR (not cleaned up for debugging)"
# rm -rf "$TEST_DIR"

echo "PASS: All allow file tests passed"
echo "✓ Explicit allow file works"
echo "✓ Default .emoji-sad-allow works"
echo "✓ Empty allow file removes all emojis"
echo "✓ Stdin processing respects allow file"
echo "✓ List-only mode respects allow file"
echo "✓ JSON output respects allow file"
echo