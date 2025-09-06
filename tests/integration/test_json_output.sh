#!/bin/bash

# Integration test for --output json functionality

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_DIR/bin/emoji-sad"

echo "=== Testing JSON Output Functionality ==="

# Test configuration
TEST_DIR="/tmp/emoji_test_json_$$"

# Setup test data
echo "Setting up test data..."
mkdir -p "$TEST_DIR/subdir"

# Create files with and without emojis
echo "Hello 😊 World 🚀" > "$TEST_DIR/file1.txt"
echo "No emojis here" > "$TEST_DIR/file2.txt" 
echo "Another emoji test 🎉 ✨" > "$TEST_DIR/file3.md"
echo "More content 🌟" > "$TEST_DIR/subdir/nested.txt"
echo "Clean nested file" > "$TEST_DIR/subdir/clean.txt"

echo "Test directory structure created"

# Test 1: JSON output with dry-run (default)
echo "Test 1: Testing JSON output with dry-run..."
output=$("$BINARY" --output json "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: JSON output command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

echo "JSON output (dry-run):"
echo "$output"
echo

# Validate JSON structure
if ! echo "$output" | jq . >/dev/null 2>&1; then
    echo "FAIL: Output is not valid JSON"
    exit 1
fi

# Check required fields exist
if ! echo "$output" | jq -e '.summary' >/dev/null 2>&1; then
    echo "FAIL: JSON output missing 'summary' field"
    exit 1
fi

if ! echo "$output" | jq -e '.files' >/dev/null 2>&1; then
    echo "FAIL: JSON output missing 'files' field"
    exit 1
fi

# Check summary fields
if ! echo "$output" | jq -e '.summary.total_files' >/dev/null 2>&1; then
    echo "FAIL: JSON output missing 'summary.total_files'"
    exit 1
fi

if ! echo "$output" | jq -e '.summary.total_emojis' >/dev/null 2>&1; then
    echo "FAIL: JSON output missing 'summary.total_emojis'"
    exit 1
fi

if ! echo "$output" | jq -e '.summary.dry_run' >/dev/null 2>&1; then
    echo "FAIL: JSON output missing 'summary.dry_run'"
    exit 1
fi

if ! echo "$output" | jq -e '.summary.mode' >/dev/null 2>&1; then
    echo "FAIL: JSON output missing 'summary.mode'"
    exit 1
fi

# Verify values
total_files=$(echo "$output" | jq -r '.summary.total_files')
total_emojis=$(echo "$output" | jq -r '.summary.total_emojis')
dry_run=$(echo "$output" | jq -r '.summary.dry_run')
mode=$(echo "$output" | jq -r '.summary.mode')

if [ "$total_files" != "3" ]; then
    echo "FAIL: Expected 3 files with emojis, got $total_files"
    exit 1
fi

if [ "$total_emojis" != "5" ]; then
    echo "FAIL: Expected 5 total emojis, got $total_emojis"
    exit 1
fi

if [ "$dry_run" != "true" ]; then
    echo "FAIL: Expected dry_run=true, got $dry_run"
    exit 1
fi

if [ "$mode" != "process" ]; then
    echo "FAIL: Expected mode=process, got $mode"
    exit 1
fi

echo "✓ JSON dry-run output structure and values are correct"

# Test 2: JSON output with --list-only
echo "Test 2: Testing JSON output with --list-only..."
list_output=$("$BINARY" --output json --list-only "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: JSON list-only command failed with exit code $exit_code"
    echo "Output: $list_output"
    exit 1
fi

echo "JSON list-only output:"
echo "$list_output"
echo

# Validate JSON structure
if ! echo "$list_output" | jq . >/dev/null 2>&1; then
    echo "FAIL: List output is not valid JSON"
    exit 1
fi

# Check mode is "list"
list_mode=$(echo "$list_output" | jq -r '.summary.mode')
if [ "$list_mode" != "list" ]; then
    echo "FAIL: Expected mode=list, got $list_mode"
    exit 1
fi

echo "✓ JSON list-only output is correct"

# Test 3: JSON output with --no-dry-run
echo "Test 3: Testing JSON output with --no-dry-run..."
actual_output=$("$BINARY" --output json --no-dry-run "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: JSON no-dry-run command failed with exit code $exit_code"
    echo "Output: $actual_output"
    exit 1
fi

echo "JSON no-dry-run output:"
echo "$actual_output"
echo

# Validate JSON structure
if ! echo "$actual_output" | jq . >/dev/null 2>&1; then
    echo "FAIL: No-dry-run output is not valid JSON"
    exit 1
fi

# Check dry_run is false
actual_dry_run=$(echo "$actual_output" | jq -r '.summary.dry_run')
if [ "$actual_dry_run" != "false" ]; then
    echo "FAIL: Expected dry_run=false, got $actual_dry_run"
    exit 1
fi

# Check that files have new_size field when modified
files_with_new_size=$(echo "$actual_output" | jq '[.files[] | select(.modified == true and .new_size)] | length')
if [ "$files_with_new_size" != "3" ]; then
    echo "FAIL: Expected 3 files with new_size field, got $files_with_new_size"
    exit 1
fi

echo "✓ JSON no-dry-run output is correct"

# Test 4: JSON output with exclusions
echo "Test 4: Testing JSON output with exclusions..."

# Restore files for exclusion test
echo "Hello 😊 World 🚀" > "$TEST_DIR/file1.txt"
echo "Another emoji test 🎉 ✨" > "$TEST_DIR/file3.md"
echo "More content 🌟" > "$TEST_DIR/subdir/nested.txt"

exclude_output=$("$BINARY" --output json --exclude "*.md" "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: JSON exclude command failed with exit code $exit_code"
    echo "Output: $exclude_output"
    exit 1
fi

# Check that .md file was excluded
excluded_files=$(echo "$exclude_output" | jq '.summary.total_files')
if [ "$excluded_files" != "2" ]; then
    echo "FAIL: Expected 2 files after exclusion, got $excluded_files"
    exit 1
fi

# Check that no .md files appear in results
md_files=$(echo "$exclude_output" | jq '[.files[] | select(.file_path | endswith(".md"))] | length')
if [ "$md_files" != "0" ]; then
    echo "FAIL: Expected 0 .md files, got $md_files"
    exit 1
fi

echo "✓ JSON output with exclusions is correct"

# Test 5: JSON output with no results
echo "Test 5: Testing JSON output with no emoji files..."
clean_dir="/tmp/emoji_test_clean_$$"
mkdir -p "$clean_dir"
echo "No emojis here" > "$clean_dir/clean.txt"

empty_output=$("$BINARY" --output json "$clean_dir" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: JSON clean directory command failed with exit code $exit_code"
    echo "Output: $empty_output"
    exit 1
fi

# Validate JSON structure for empty results
if ! echo "$empty_output" | jq . >/dev/null 2>&1; then
    echo "FAIL: Empty output is not valid JSON"
    exit 1
fi

empty_files=$(echo "$empty_output" | jq '.summary.total_files')
empty_emojis=$(echo "$empty_output" | jq '.summary.total_emojis')

if [ "$empty_files" != "0" ]; then
    echo "FAIL: Expected 0 files for clean directory, got $empty_files"
    exit 1
fi

if [ "$empty_emojis" != "0" ]; then
    echo "FAIL: Expected 0 emojis for clean directory, got $empty_emojis"
    exit 1
fi

echo "✓ JSON output with no results is correct"

# Test 6: Invalid output format
echo "Test 6: Testing invalid output format..."
invalid_output=$("$BINARY" --output invalid "$TEST_DIR" 2>&1 || true)
if echo "$invalid_output" | grep -q "invalid output format"; then
    echo "✓ Invalid output format correctly rejected"
else
    echo "FAIL: Invalid output format should be rejected"
    exit 1
fi

# Test 7: Short flag -o
echo "Test 7: Testing short flag -o json..."
short_output=$("$BINARY" -o json "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Short flag -o json failed with exit code $exit_code"
    exit 1
fi

if ! echo "$short_output" | jq . >/dev/null 2>&1; then
    echo "FAIL: Short flag output is not valid JSON"
    exit 1
fi

echo "✓ Short flag -o json works correctly"

# Test 8: JSON output with stdin file list input
echo "Test 8: Testing JSON output with stdin file list input..."

# Restore files for stdin test
echo "Hello 😊 World 🚀" > "$TEST_DIR/stdin1.txt"
echo "Another emoji test 🎉 ✨" > "$TEST_DIR/stdin2.txt"

# Create a list of files to process via stdin
echo "$TEST_DIR/stdin1.txt" > /tmp/stdin_files_$$
echo "$TEST_DIR/stdin2.txt" >> /tmp/stdin_files_$$

stdin_json_output=$(cat /tmp/stdin_files_$$ | "$BINARY" --files-from-stdin --output json - 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Stdin JSON output failed with exit code $exit_code"
    echo "Output: $stdin_json_output"
    exit 1
fi

echo "JSON stdin file list output:"
echo "$stdin_json_output"
echo

# Validate JSON structure
if ! echo "$stdin_json_output" | jq . >/dev/null 2>&1; then
    echo "FAIL: Stdin JSON output is not valid JSON"
    exit 1
fi

# Check that we got the expected files
stdin_files=$(echo "$stdin_json_output" | jq '.summary.total_files')
stdin_emojis=$(echo "$stdin_json_output" | jq '.summary.total_emojis')

if [ "$stdin_files" != "2" ]; then
    echo "FAIL: Expected 2 files from stdin, got $stdin_files"
    exit 1
fi

if [ "$stdin_emojis" != "4" ]; then
    echo "FAIL: Expected 4 emojis from stdin, got $stdin_emojis"
    exit 1
fi

# Check that file paths are correct
file_paths=$(echo "$stdin_json_output" | jq -r '.files[].file_path' | sort)
expected_path1="$TEST_DIR/stdin1.txt"
expected_path2="$TEST_DIR/stdin2.txt"

if ! echo "$file_paths" | grep -q "$expected_path1"; then
    echo "FAIL: Expected to find $expected_path1 in results"
    exit 1
fi

if ! echo "$file_paths" | grep -q "$expected_path2"; then
    echo "FAIL: Expected to find $expected_path2 in results"
    exit 1
fi

echo "✓ JSON output with stdin file list input works correctly"

# Clean up stdin test files
rm -f /tmp/stdin_files_$$

# Test 9: JSON output with direct file content piping (cat file | emoji-sad -)
echo "Test 9: Testing JSON output with direct file content piping..."

# Create a test file with emojis for direct content piping
echo "Direct content with emojis 🎯 🔥 ⚡ from file" > "$TEST_DIR/direct_content.txt"

# Test piping file content directly (new default behavior - processes content)
direct_content_output=$(cat "$TEST_DIR/direct_content.txt" | "$BINARY" --output json - 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Direct content piping failed with exit code $exit_code"
    echo "Output: $direct_content_output"
    exit 1
fi

echo "JSON direct content piping output:"
echo "$direct_content_output"
echo

# Validate JSON structure
if ! echo "$direct_content_output" | jq . >/dev/null 2>&1; then
    echo "FAIL: Direct content piping output is not valid JSON"
    exit 1
fi

# Now direct content piping processes the content and should find emojis
direct_files=$(echo "$direct_content_output" | jq '.summary.total_files')
direct_emojis=$(echo "$direct_content_output" | jq '.summary.total_emojis')

if [ "$direct_files" != "1" ]; then
    echo "FAIL: Expected 1 file (<stdin>) from direct content piping, got $direct_files"
    exit 1
fi

if [ "$direct_emojis" != "3" ]; then
    echo "FAIL: Expected 3 emojis from direct content piping, got $direct_emojis"
    exit 1
fi

# Check that file path is <stdin>
stdin_path=$(echo "$direct_content_output" | jq -r '.files[0].file_path')
if [ "$stdin_path" != "<stdin>" ]; then
    echo "FAIL: Expected file path to be <stdin>, got $stdin_path"
    exit 1
fi

echo "✓ JSON output with direct file content piping works correctly (processes content directly)"

# Clean up
rm -rf "$TEST_DIR" "$clean_dir" 2>/dev/null || true

echo "PASS: All JSON output tests passed"
echo "✓ JSON structure validation"
echo "✓ Dry-run mode JSON output"
echo "✓ List-only mode JSON output"  
echo "✓ No-dry-run mode JSON output"
echo "✓ JSON output with exclusions"
echo "✓ JSON output with no results"
echo "✓ Invalid format rejection"
echo "✓ Short flag support"
echo "✓ JSON output with stdin file list input"
echo "✓ JSON output with direct file content piping"
echo