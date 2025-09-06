#!/bin/bash

# Integration test for handling special file types (sockets, VCS directories, etc.)

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_DIR/bin/emoji-sad"

echo "=== Testing Special File Types ==="

# Test configuration
TEST_DIR="/tmp/emoji_test_special_$$"

# Setup test directory with special files
echo "Setting up test data with special file types..."
mkdir -p "$TEST_DIR"

# Create regular files with emojis
echo "Regular file with emoji 😊" > "$TEST_DIR/regular.txt"
echo "Another file 🚀" > "$TEST_DIR/another.md"

# Create .git directory structure (should be skipped)
mkdir -p "$TEST_DIR/.git/objects/ab"
mkdir -p "$TEST_DIR/.git/hooks"
echo "fake git object with emoji 😊" > "$TEST_DIR/.git/objects/ab/1234567890"
echo "another git file 🔥" > "$TEST_DIR/.git/hooks/pre-commit"

# Create .svn directory (should be skipped)
mkdir -p "$TEST_DIR/.svn"
echo "svn file with emoji ✨" > "$TEST_DIR/.svn/entries"

# Create .hg directory (should be skipped) 
mkdir -p "$TEST_DIR/.hg"
echo "mercurial file 🎯" > "$TEST_DIR/.hg/dirstate"

# Create binary files (should be skipped)
echo -e "\x00\x01\x02\x03😊\x04\x05" > "$TEST_DIR/binary.bin"
dd if=/dev/zero of="$TEST_DIR/image.jpg" bs=1024 count=1 2>/dev/null

# Create socket file extension (should be skipped by extension)
echo "socket-like file 💯" > "$TEST_DIR/app.sock"

echo "Test directory structure created"

# Test 1: Default behavior should skip special files
echo "Test 1: Running with default behavior (dry-run)..."
output=$("$BINARY" "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

echo "Output:"
echo "$output"
echo

# Verify output contains expected behavior
if ! echo "$output" | grep -q "DRY RUN:"; then
    echo "FAIL: Should show dry-run output"
    exit 1
fi

# Should find regular files with emojis
if ! echo "$output" | grep -q "regular.txt"; then
    echo "FAIL: Should find regular.txt"
    exit 1
fi

if ! echo "$output" | grep -q "another.md"; then
    echo "FAIL: Should find another.md"
    exit 1
fi

# Should NOT find VCS files
if echo "$output" | grep -q "\.git"; then
    echo "FAIL: Should not process .git files"
    exit 1
fi

if echo "$output" | grep -q "\.svn"; then
    echo "FAIL: Should not process .svn files"
    exit 1
fi

if echo "$output" | grep -q "\.hg"; then
    echo "FAIL: Should not process .hg files"
    exit 1
fi

# Should NOT find binary files
if echo "$output" | grep -q "binary.bin"; then
    echo "FAIL: Should not process binary files"
    exit 1
fi

if echo "$output" | grep -q "image.jpg"; then
    echo "FAIL: Should not process image files"
    exit 1
fi

# Should NOT find socket files
if echo "$output" | grep -q "app.sock"; then
    echo "FAIL: Should not process socket files"
    exit 1
fi

# Count number of files processed (should be exactly 2: regular.txt and another.md)
file_count=$(echo "$output" | grep -c "File:" || true)
if [ "$file_count" -ne 2 ]; then
    echo "FAIL: Expected exactly 2 files to be processed, got $file_count"
    exit 1
fi

echo "✓ Correctly skips VCS directories"
echo "✓ Correctly skips binary files"
echo "✓ Correctly skips socket files"
echo "✓ Processes only regular text files"

# Test 2: Actual processing with --no-dry-run
echo "Test 2: Running with --no-dry-run..."
output=$("$BINARY" --no-dry-run "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: --no-dry-run command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

# Verify files were actually modified
if grep -q "😊" "$TEST_DIR/regular.txt"; then
    echo "FAIL: regular.txt should have had emoji removed"
    exit 1
fi

if grep -q "🚀" "$TEST_DIR/another.md"; then
    echo "FAIL: another.md should have had emoji removed"
    exit 1
fi

# Verify VCS files were NOT modified (still contain emojis)
if ! grep -q "😊" "$TEST_DIR/.git/objects/ab/1234567890"; then
    echo "FAIL: VCS files should not be modified"
    exit 1
fi

echo "✓ --no-dry-run works correctly with special files"

# Clean up
rm -rf "$TEST_DIR"

echo "PASS: Special file handling works correctly"
echo "✓ VCS directories are properly skipped"
echo "✓ Binary files are properly skipped"  
echo "✓ Socket files are properly skipped"
echo "✓ Regular text files are processed correctly"
echo "✓ Tool handles mixed directory contents safely"
echo