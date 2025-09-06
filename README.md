# Emoji Search and Destroy (emoji-sad)

> **Note**: This is example code used for other projects to test against. It should work as a functional emoji remover, but its primary purpose is to serve as a reference implementation and testing target. As well, it is used in testing AI-Assisted coding tools to ensure there are no emojies in the code or other files.

A command-line tool that recursively searches through directories to find and remove all emojis from text files. By default, the tool runs in dry-run mode to preview changes. Use `--no-dry-run` to actually modify files.

## Features

| Feature | Description |
|---------|-------------|
| **Recursive Directory Processing** | Walks through all files in a directory tree |
| **Comprehensive Emoji Detection** | Detects various emoji Unicode ranges |
| **Safe by Default** | Runs in dry-run mode by default to preview changes |
| **Detailed Reporting** | Shows which emojis were found and file size changes |
| **Smart File Filtering** | Automatically skips binary files |
| **Fast Processing** | Efficient regex-based emoji detection |
| **Stdin Processing** | Process content directly from stdin or file paths |
| **Exclusion Patterns** | Exclude specific files or directories with glob patterns |
| **JSON Output** | Machine-readable JSON format for integration with other tools |
| **Quiet Mode** | Suppress reports for clean Unix piping |
| **List Mode** | List files with emojis without processing them |
| **Emoji Allow Lists** | Preserve specific emojis using allow files |

## Installation

### Download Pre-built Binary (Linux)

```bash
# Download latest release (replace VERSION with desired version, e.g., v0.1.5)
VERSION=v0.1.5
curl -L https://github.com/ccollicutt/emoji-search-and-destroy/releases/download/${VERSION}/emoji-sad-linux-amd64.tar.gz | tar xz
chmod +x emoji-sad
sudo mv emoji-sad /usr/local/bin/
```

### Build from Source

#### Prerequisites

- Go 1.23 or later

```bash
git clone https://github.com/ccollicutt/emoji-search-and-destroy
cd emoji-search-and-destroy
make build
```

The binary will be created at `./bin/emoji-sad`.

## Usage

### Basic Usage

```bash
# Preview emoji removal from current directory (dry-run)
emoji-sad .

# Actually remove emojis from a specific directory
emoji-sad --no-dry-run /path/to/project

# Only list files containing emojis
emoji-sad -l /path/to/project

# Process content from stdin directly
cat file.txt | emoji-sad -

# Process file paths from stdin
find . -name "*.txt" | emoji-sad - --files-from-stdin

# Show help
emoji-sad --help
```

### Examples

**Preview what emojis would be removed (default behavior):**
```bash
$ emoji-sad ./my-project
DRY RUN: Found emojis in 3 file(s):

File: ./my-project/README.md
  Emojis found: [🚀 ✨ 🎉]
  Would reduce size: 1024 → 1015 bytes

Total: Would remove 3 emoji(s) from 3 file(s)
Run with --no-dry-run to actually remove emojis.
```

**Actually remove emojis:**
```bash
$ emoji-sad --no-dry-run ./my-project
Processed 3 file(s) and removed emojis:

File: ./my-project/README.md
  Emojis found: [🚀 ✨ 🎉]
  Size changed: 1024 → 1015 bytes

Total: Removed 3 emoji(s) from 3 file(s)
```

**List files containing emojis:**
```bash
$ emoji-sad --list-only ./my-project
./my-project/README.md
./my-project/src/main.js
./my-project/docs/guide.md
```

**Process content from stdin directly (default for stdin):**
```bash
# Clean emoji content from a file
$ cat file.txt | emoji-sad -
Hello  World  Test

# Use with quiet mode to suppress reports
$ echo "Hello 😊 World" | emoji-sad --quiet --no-dry-run -
Hello  World
```

**Process file paths from stdin:**
```bash
# Process specific file types
$ find . -name "*.md" | emoji-sad - --files-from-stdin

# Remove emojis from files listed in a file
$ cat file_list.txt | emoji-sad - --files-from-stdin --no-dry-run
```

**Exclude specific files or directories:**
```bash
# Exclude node_modules and test files
$ emoji-sad . --exclude node_modules --exclude "*.test.js"

# Exclude specific paths
$ emoji-sad . --exclude /path/to/skip --exclude config.json
```

**Output results in JSON format:**
```bash
# JSON output for directory processing
$ emoji-sad . --output json

# JSON with list-only mode
$ emoji-sad -l . -o json

# JSON for stdin processing
$ find . -name "*.txt" | emoji-sad -o json - --files-from-stdin
```

**Quiet mode for clean piping:**
```bash
# Process content silently (only output cleaned content)
$ cat file.txt | emoji-sad --quiet --no-dry-run -

# Use short flag
$ echo "Test 😊" | emoji-sad -q --no-dry-run -
```

**Use emoji allow lists to preserve specific emojis:**
```bash
# Create an allow list file
$ echo "✅" > allowed.txt
$ echo "🚀" >> allowed.txt

# Use explicit allow file
$ emoji-sad --allow-file allowed.txt ./my-project

# Create default allow file (automatically used if present)
$ echo "✅" > .emoji-sad-allow
$ emoji-sad ./my-project  # Will preserve ✅ emojis
```

## Command Line Options

| Flag | Short | Description |
|------|-------|-------------|
| `--no-dry-run` | | Actually modify files instead of previewing (default is dry-run) |
| `--list-only` | `-l` | Only list files containing emojis, one per line |
| `--exclude strings` | | Exclude files or directories matching these patterns (can be used multiple times) |
| `--output string` | `-o` | Output format: text or json (default "text") |
| `--files-from-stdin` | | Read file paths from stdin instead of processing stdin content directly |
| `--quiet` | `-q` | Suppress processing reports (only output cleaned content for stdin) |
| `--allow-file string` | `-a` | File containing allowed emojis, one per line (default: .emoji-sad-allow if it exists) |
| `--help` | `-h` | Show help information |
| `--version` | `-v` | Show version information |

## Arguments

| Argument | Description |
|----------|-------------|
| `directory` | Directory to process recursively |
| `-` | Process content from stdin (default) or file paths with `--files-from-stdin` |

## File Processing

### How Files Are Identified

The tool automatically identifies and skips special files to avoid corruption:

1. **File Type Detection**: Uses `os.Stat()` to check file mode
   - Skips non-regular files (sockets, devices, pipes, symbolic links)
   - Only processes regular files

2. **Extension-Based Filtering**: Skips known binary file extensions:
   - **Executables**: `.exe`, `.bin`, `.so`, `.dll`
   - **Images**: `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`  
   - **Media**: `.mp3`, `.mp4`, `.avi`, `.mov`
   - **Archives**: `.zip`, `.tar`, `.gz`, `.7z`
   - **Documents**: `.pdf`
   - **Special**: `.sock`

3. **Directory Filtering**: Automatically skips version control directories:
   - `.git/`, `.svn/`, `.hg/`

### Supported File Types

All text files are processed by default, including:
- Source code files (`.js`, `.py`, `.go`, `.java`, etc.)
- Documentation files (`.md`, `.txt`, `.rst`)
- Configuration files (`.json`, `.yaml`, `.xml`, `.ini`)
- Web files (`.html`, `.css`, `.svg`)
- Any file without a known binary extension

## Technical Details

### Emoji Allow Lists

The tool supports preserving specific emojis by using allow lists:

**Allow File Format:**
- One emoji per line
- Lines starting with `#` are treated as comments
- Empty lines are ignored
- Unicode emojis are fully supported

**Default Behavior:**
- If no `--allow-file` is specified, the tool looks for `.emoji-sad-allow` in the current directory
- If neither explicit allow file nor default file exists, all emojis are removed
- Allow lists work with all modes: directory processing, stdin, list-only, and JSON output

**Example Allow File:**
```
# Common allowed emojis
✅
🚀
🎯

# Another comment
⭐
```

### Emoji Detection

The tool uses a combination of:
- Regular expressions for common emoji Unicode ranges
- Character-by-character analysis for comprehensive coverage
- Allow list filtering to preserve specified emojis

### Unicode Ranges Covered

- `\u1F600-\u1F64F` - Emoticons
- `\u1F300-\u1F5FF` - Misc Symbols and Pictographs
- `\u1F680-\u1F6FF` - Transport and Map Symbols
- `\u1F1E0-\u1F1FF` - Regional Indicator Symbols
- `\u2600-\u26FF` - Miscellaneous Symbols
- `\u2700-\u27BF` - Dingbats
- `\u1F900-\u1F9FF` - Supplemental Symbols and Pictographs

