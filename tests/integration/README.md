# Integration Tests

This directory contains bash integration tests for the emoji-search-and-destroy CLI tool.

## Test Structure

- `run_tests.sh` - Main test runner
- `test_dry_run.sh` - Tests dry-run functionality
- `test_emoji_removal.sh` - Tests actual emoji removal
- `test_default_behavior.sh` - Tests default behavior and --no-dry-run flag
- `test_edge_cases.sh` - Tests edge cases and error conditions
- `test_special_files.sh` - Tests special file handling
- `test_list_and_stdin.sh` - Tests list mode and stdin processing
- `test_version.sh` - Tests version output
- `test_exclude_flag.sh` - Tests exclusion patterns
- `test_json_output.sh` - Tests JSON output format
- `test_quiet_mode.sh` - Tests quiet mode functionality

## Running Tests

### Run All Tests
```bash
# From project root
./tests/integration/run_tests.sh
```

### Run Individual Tests
```bash
# Dry-run tests
./tests/integration/test_dry_run.sh

# Emoji removal tests
./tests/integration/test_emoji_removal.sh

# Edge case tests
./tests/integration/test_edge_cases.sh
```

## Prerequisites

1. Build the binary:
   ```bash
   make build
   ```

2. Ensure all test scripts are executable:
   ```bash
   chmod +x tests/integration/*.sh
   ```

## Test Coverage

### Dry-Run Tests
- Verifies files are not modified during dry-run
- Checks output format and messaging
- Confirms correct emoji detection

### Emoji Removal Tests
- Verifies actual emoji removal from various file types
- Ensures clean files are not modified
- Tests nested directory processing
- Validates output format

### Edge Case Tests
- Non-existent directories
- Empty directories
- Binary file handling
- Unicode character preservation
- Large file processing
- Help and error conditions

## Test Data

Tests create temporary directories with various file types:
- Plain text files with emojis
- Markdown files with mixed content
- JSON files with emoji values
- Go source files with emoji comments
- Binary files (skipped)
- Nested directory structures

## Expected Behavior

- Binary files are skipped based on extension
- Unicode characters (non-emoji) are preserved
- Directory traversal works recursively
- Dry-run mode shows preview without changes
- Error conditions are handled gracefully