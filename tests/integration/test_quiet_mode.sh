#!/bin/bash

# Integration test for --quiet/-q flag functionality

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_DIR/bin/emoji-sad"

echo "=== Testing Quiet Mode Functionality ==="

# Test configuration
TEST_DIR="/tmp/emoji_test_quiet_$$"

# Setup test data
echo "Setting up test data..."
mkdir -p "$TEST_DIR/subdir"

# Create files with and without emojis
echo "Hello 😊 World 🚀" > "$TEST_DIR/file1.txt"
echo "No emojis here" > "$TEST_DIR/file2.txt" 
echo "Another emoji test 🎉 ✨" > "$TEST_DIR/file3.md"
echo "More content 🌟" > "$TEST_DIR/subdir/nested.txt"

echo "Test directory structure created"

# Test 1: Directory processing with --quiet (should suppress all output)
echo "Test 1: Testing --quiet with directory processing..."
output=$("$BINARY" --quiet "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Quiet directory processing failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

# Should be completely silent
if [ -n "$output" ]; then
    echo "FAIL: --quiet should suppress all output, got: '$output'"
    exit 1
fi

echo "✓ Quiet mode suppresses directory processing output"

# Test 2: Directory processing with --quiet --no-dry-run (should suppress all output)
echo "Test 2: Testing --quiet --no-dry-run with directory processing..."

# Restore emojis first
echo "Hello 😊 World 🚀" > "$TEST_DIR/file1.txt"
echo "Another emoji test 🎉 ✨" > "$TEST_DIR/file3.md"

output_nodry=$("$BINARY" --quiet --no-dry-run "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Quiet no-dry-run directory processing failed with exit code $exit_code"
    echo "Output: $output_nodry"
    exit 1
fi

# Should be completely silent
if [ -n "$output_nodry" ]; then
    echo "FAIL: --quiet --no-dry-run should suppress all output, got: '$output_nodry'"
    exit 1
fi

# Verify files were actually processed
if grep -q "😊" "$TEST_DIR/file1.txt"; then
    echo "FAIL: Files should have been processed even in quiet mode"
    exit 1
fi

echo "✓ Quiet mode suppresses directory processing output but still processes files"

# Test 3: --quiet with --list-only (should still show file list)
echo "Test 3: Testing --quiet with --list-only..."

# Restore emojis for list test
echo "Hello 😊 World 🚀" > "$TEST_DIR/file1.txt"
echo "Another emoji test 🎉 ✨" > "$TEST_DIR/file3.md"

list_output=$("$BINARY" --quiet --list-only "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Quiet list-only failed with exit code $exit_code"
    echo "Output: $list_output"
    exit 1
fi

# Should show file paths (list-only overrides quiet for output)
if [ -z "$list_output" ]; then
    echo "FAIL: --quiet --list-only should still show file paths"
    exit 1
fi

# Check that it shows the expected files
if ! echo "$list_output" | grep -q "file1.txt"; then
    echo "FAIL: Should list file1.txt"
    exit 1
fi

if ! echo "$list_output" | grep -q "file3.md"; then
    echo "FAIL: Should list file3.md"
    exit 1
fi

echo "✓ Quiet mode with --list-only still shows file paths"

# Test 4: Stdin content processing with --quiet (should only output cleaned content)
echo "Test 4: Testing --quiet with stdin content processing..."

stdout_only=$(echo "Hello 😊 World 🚀 Test" | "$BINARY" --quiet --no-dry-run -)
stderr_output=$(echo "Hello 😊 World 🚀 Test" | "$BINARY" --quiet --no-dry-run - 2>&1 >/dev/null)

# Check stdout has only cleaned content
if [ "$stdout_only" != "Hello  World  Test" ]; then
    echo "FAIL: Expected cleaned content 'Hello  World  Test', got '$stdout_only'"
    exit 1
fi

# Check stderr is empty (quiet mode)
if [ -n "$stderr_output" ]; then
    echo "FAIL: --quiet should suppress stderr output, got: '$stderr_output'"
    exit 1
fi

echo "✓ Quiet mode with stdin content processing only outputs cleaned content"

# Test 5: Stdin content processing with --quiet dry-run (should only output cleaned content preview)
echo "Test 5: Testing --quiet with stdin content dry-run..."

dry_stdout=$(echo "Hello 😊 World 🚀 Test" | "$BINARY" --quiet -)
dry_stderr=$(echo "Hello 😊 World 🚀 Test" | "$BINARY" --quiet - 2>&1 >/dev/null)

# In dry-run mode with quiet, should show no output at all
if [ -n "$dry_stdout" ]; then
    echo "FAIL: --quiet dry-run should suppress stdout, got: '$dry_stdout'"
    exit 1
fi

if [ -n "$dry_stderr" ]; then
    echo "FAIL: --quiet dry-run should suppress stderr, got: '$dry_stderr'"
    exit 1
fi

echo "✓ Quiet mode with stdin dry-run suppresses all output"

# Test 6: File list processing with --quiet
echo "Test 6: Testing --quiet with file list processing..."

# Restore emojis and create file list
echo "Hello 😊 World 🚀" > "$TEST_DIR/list1.txt"
echo "Another emoji test 🎉" > "$TEST_DIR/list2.txt"

echo "$TEST_DIR/list1.txt" > /tmp/file_list_$$
echo "$TEST_DIR/list2.txt" >> /tmp/file_list_$$

filelist_output=$(cat /tmp/file_list_$$ | "$BINARY" --quiet --files-from-stdin --no-dry-run - 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Quiet file list processing failed with exit code $exit_code"
    echo "Output: $filelist_output"
    exit 1
fi

# Should be silent
if [ -n "$filelist_output" ]; then
    echo "FAIL: --quiet with file list should suppress output, got: '$filelist_output'"
    exit 1
fi

# Verify files were processed
if grep -q "😊\|🎉" "$TEST_DIR/list1.txt" "$TEST_DIR/list2.txt"; then
    echo "FAIL: Files should have been processed in quiet mode"
    exit 1
fi

echo "✓ Quiet mode with file list processing suppresses output but processes files"

# Test 7: Short flag -q
echo "Test 7: Testing short flag -q..."

short_output=$(echo "Hello 😊 Test" | "$BINARY" -q --no-dry-run -)
if [ "$short_output" != "Hello  Test" ]; then
    echo "FAIL: Short flag -q should work like --quiet"
    exit 1
fi

echo "✓ Short flag -q works correctly"

# Test 8: JSON output with --quiet (JSON should still be output)
echo "Test 8: Testing --quiet with JSON output..."

json_output=$(echo "Hello 😊 World" | "$BINARY" --quiet --output json -)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Quiet JSON output failed with exit code $exit_code"
    exit 1
fi

# JSON should still be output even in quiet mode
if [ -z "$json_output" ]; then
    echo "FAIL: JSON output should still work in quiet mode"
    exit 1
fi

# Validate it's valid JSON
if ! echo "$json_output" | jq . >/dev/null 2>&1; then
    echo "FAIL: Quiet mode JSON output should be valid JSON"
    exit 1
fi

echo "✓ Quiet mode with JSON output still produces JSON"

# Clean up
rm -rf "$TEST_DIR" /tmp/file_list_$$ 2>/dev/null || true

echo "PASS: All quiet mode tests passed"
echo "✓ Quiet mode suppresses directory processing output"
echo "✓ Quiet mode works with --no-dry-run"
echo "✓ Quiet mode preserves --list-only output"
echo "✓ Quiet mode with stdin content shows only cleaned content"
echo "✓ Quiet mode with stdin dry-run suppresses all output"
echo "✓ Quiet mode with file list processing works"
echo "✓ Short flag -q works"
echo "✓ Quiet mode preserves JSON output"
echo