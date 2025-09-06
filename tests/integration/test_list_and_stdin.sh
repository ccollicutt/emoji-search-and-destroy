#!/bin/bash

# Integration test for --list-only flag and stdin input functionality

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_DIR/bin/emoji-sad"

echo "=== Testing List-Only and Stdin Functionality ==="

# Test configuration
TEST_DIR="/tmp/emoji_test_list_stdin_$$"

# Setup test data
echo "Setting up test data..."
mkdir -p "$TEST_DIR/subdir"

# Create files with and without emojis
echo "Hello 😊 world" > "$TEST_DIR/file1.txt"
echo "No emojis here" > "$TEST_DIR/file2.txt"
echo "Another emoji 🚀 test" > "$TEST_DIR/file3.md"
echo "More emojis 🎉 ✨" > "$TEST_DIR/subdir/nested.txt"
echo "Clean nested file" > "$TEST_DIR/subdir/clean.txt"

echo "Test directory structure created"

# Test 1: --list-only flag should output only filenames
echo "Test 1: Testing --list-only flag..."
output=$("$BINARY" --list-only "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: --list-only command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

echo "List-only output:"
echo "$output"
echo

# Verify output format
if echo "$output" | grep -q "DRY RUN:\|File:\|Emojis found:"; then
    echo "FAIL: --list-only should not show detailed output"
    exit 1
fi

# Should contain files with emojis
if ! echo "$output" | grep -q "file1.txt"; then
    echo "FAIL: Should list file1.txt"
    exit 1
fi

if ! echo "$output" | grep -q "file3.md"; then
    echo "FAIL: Should list file3.md"
    exit 1
fi

if ! echo "$output" | grep -q "nested.txt"; then
    echo "FAIL: Should list nested.txt"
    exit 1
fi

# Should NOT contain files without emojis
if echo "$output" | grep -q "file2.txt\|clean.txt"; then
    echo "FAIL: Should not list files without emojis"
    exit 1
fi

# Count number of lines (should be 3 files with emojis)
line_count=$(echo "$output" | wc -l)
if [ "$line_count" -ne 3 ]; then
    echo "FAIL: Expected 3 files listed, got $line_count"
    exit 1
fi

echo "✓ --list-only correctly lists only files with emojis"

# Test 2: Stdin input with file list
echo "Test 2: Testing stdin input..."

# Create a file list
echo "$TEST_DIR/file1.txt" > /tmp/file_list_$$
echo "$TEST_DIR/file3.md" >> /tmp/file_list_$$
echo "$TEST_DIR/subdir/nested.txt" >> /tmp/file_list_$$

# Test dry-run with stdin file list (using new --files-from-stdin flag)
stdin_output=$(cat /tmp/file_list_$$ | "$BINARY" --files-from-stdin - 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: stdin dry-run command failed with exit code $exit_code"
    echo "Output: $stdin_output"
    exit 1
fi

echo "Stdin dry-run output:"
echo "$stdin_output"
echo

# Verify stdin output
if ! echo "$stdin_output" | grep -q "DRY RUN:"; then
    echo "FAIL: stdin should show dry-run output by default"
    exit 1
fi

if ! echo "$stdin_output" | grep -q "file1.txt\|file3.md\|nested.txt"; then
    echo "FAIL: stdin should process specified files"
    exit 1
fi

echo "✓ Stdin input works with dry-run"

# Test 3: Stdin with --no-dry-run
echo "Test 3: Testing stdin with --no-dry-run..."

# Store original content
original_file1=$(cat "$TEST_DIR/file1.txt")
original_file3=$(cat "$TEST_DIR/file3.md")

# Process with --no-dry-run
stdin_actual_output=$(cat /tmp/file_list_$$ | "$BINARY" --files-from-stdin --no-dry-run - 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: stdin --no-dry-run command failed with exit code $exit_code"
    echo "Output: $stdin_actual_output"
    exit 1
fi

# Verify files were actually modified
if grep -q "😊" "$TEST_DIR/file1.txt"; then
    echo "FAIL: file1.txt should have had emojis removed"
    exit 1
fi

if grep -q "🚀" "$TEST_DIR/file3.md"; then
    echo "FAIL: file3.md should have had emojis removed"
    exit 1
fi

# Verify files still contain text
if ! grep -q "Hello.*world" "$TEST_DIR/file1.txt"; then
    echo "FAIL: file1.txt should still contain text content"
    exit 1
fi

echo "✓ Stdin input with --no-dry-run modifies files"

# Test 4: Error handling for non-existent files in stdin
echo "Test 4: Testing error handling for non-existent files..."

echo "/non/existent/file.txt" | "$BINARY" --files-from-stdin - 2>error_output_$$ >/dev/null || true
if ! grep -q "Warning.*does not exist" error_output_$$; then
    echo "FAIL: Should warn about non-existent files"
    cat error_output_$$
    exit 1
fi

echo "✓ Properly handles non-existent files in stdin"

# Test 5: --list-only with stdin content should fail (but work with --files-from-stdin)
echo "Test 5: Testing --list-only with different stdin modes..."

# Should fail with direct content
echo "content with emoji 😊" | "$BINARY" --list-only - 2>&1 >/dev/null || content_exit_code=$?
if [ $content_exit_code -eq 0 ]; then
    echo "FAIL: --list-only with stdin content should fail"
    exit 1
fi

# Should work with --files-from-stdin
echo "$TEST_DIR/file1.txt" | "$BINARY" --list-only --files-from-stdin - 2>&1 >/dev/null || files_exit_code=$?
if [ $files_exit_code -ne 0 ]; then
    echo "FAIL: --list-only with --files-from-stdin should work"
    exit 1
fi

echo "✓ --list-only correctly handles different stdin modes"

# Test 6: Pipeline workflow
echo "Test 6: Testing complete pipeline workflow..."

# Restore test files with emojis
echo "Hello 😊 world" > "$TEST_DIR/file1.txt"
echo "Another emoji 🚀 test" > "$TEST_DIR/file3.md"

# Generate list and use it to process files
pipeline_output=$("$BINARY" --list-only "$TEST_DIR" | "$BINARY" --files-from-stdin --no-dry-run - 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Pipeline workflow failed with exit code $exit_code"
    echo "Output: $pipeline_output"
    exit 1
fi

# Verify files were processed
if grep -q "😊\|🚀" "$TEST_DIR/file1.txt" "$TEST_DIR/file3.md"; then
    echo "FAIL: Pipeline should have removed emojis"
    exit 1
fi

echo "✓ Complete pipeline workflow works"

# Test 7: Direct content processing from stdin (new default behavior)
echo "Test 7: Testing direct content processing from stdin..."

# Test with dry-run (should show report but not modify stdin)
content_output=$(echo "Hello 😊 World 🚀 Test" | "$BINARY" - 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Direct content processing failed with exit code $exit_code"
    echo "Output: $content_output"
    exit 1
fi

echo "Direct content dry-run output:"
echo "$content_output"

# Should contain stdin processing info
if ! echo "$content_output" | grep -q "DRY RUN:"; then
    echo "FAIL: Direct content should show dry-run output"
    exit 1
fi

if ! echo "$content_output" | grep -q "<stdin>"; then
    echo "FAIL: Direct content should show <stdin> as file path"
    exit 1
fi

echo "✓ Direct content processing from stdin works correctly"

# Clean up
rm -rf "$TEST_DIR" /tmp/file_list_$$ error_output_$$ 2>/dev/null || true

echo "PASS: All list-only and stdin tests passed"
echo "✓ --list-only outputs only filenames"
echo "✓ Stdin input processes file lists with --files-from-stdin"
echo "✓ --no-dry-run works with stdin file lists"
echo "✓ Error handling for non-existent files"
echo "✓ --list-only handles different stdin modes correctly"
echo "✓ Complete pipeline workflow functional"
echo "✓ Direct content processing from stdin (new default)"
echo